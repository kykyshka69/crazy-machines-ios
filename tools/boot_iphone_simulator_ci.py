#!/usr/bin/env python3
"""Bound macOS CoreSimulator boot attempts; reject a stalled simulator."""
import json
import os
import subprocess
import sys
from pathlib import Path


class SimulatorBootError(RuntimeError):
    pass


def iphone_candidates(payload):
    if not isinstance(payload, dict) or not isinstance(payload.get("devices"), dict):
        raise SimulatorBootError("simctl returned invalid devices JSON")
    result, seen = [], set()
    for devices in payload["devices"].values():
        if not isinstance(devices, list):
            continue
        for device in devices:
            if not isinstance(device, dict):
                continue
            name, udid, state = device.get("name"), device.get("udid"), device.get("state")
            if (isinstance(name, str) and name.startswith("iPhone")
                    and isinstance(udid, str) and udid not in seen
                    and state in ("Booted", "Shutdown")
                    and device.get("isAvailable", True) is not False):
                seen.add(udid)
                result.append((udid, name, state))
    result.sort(key=lambda item: (item[2] != "Booted", item[1], item[0]))
    return result


def execute(argv, *, runner=subprocess.run, timeout=45):
    try:
        completed = runner(argv, capture_output=True, text=True, timeout=timeout,
                           check=False)
    except subprocess.TimeoutExpired as error:
        raise SimulatorBootError("timeout after %ss: %s" % (
            timeout, " ".join(argv))) from error
    except OSError as error:
        raise SimulatorBootError("cannot invoke %s: %s" % (" ".join(argv), error)) from error
    if completed.returncode:
        raise SimulatorBootError("%s returned %s: %s" %
            (" ".join(argv), completed.returncode, completed.stderr[-1200:]))
    return completed.stdout


def boot_iphone(*, runner=subprocess.run, max_attempts=2,
                preferred_udid=None):
    payload = execute(["xcrun", "simctl", "list", "devices", "available", "-j"],
                      runner=runner, timeout=30)
    try:
        candidates = iphone_candidates(json.loads(payload))
    except json.JSONDecodeError as error:
        raise SimulatorBootError("invalid JSON from simctl") from error
    if not candidates:
        raise SimulatorBootError("no available iPhone Simulator device")
    # Private captures may require the same iPhone Simulator across runs.
    # Never silently use a different device if the owner requested a UDID.
    requested = preferred_udid or os.environ.get("CM_SIMULATOR_UDID")
    if requested:
        candidates = [device for device in candidates if device[0] == requested]
        if not candidates:
            raise SimulatorBootError(
                "requested iPhone Simulator is not available: " + requested)
    errors = []
    for udid, name, state in candidates[:max_attempts]:
        print("Starting %s (%s, %s)" % (name, udid, state), file=sys.stderr)
        try:
            if state != "Booted":
                execute(["xcrun", "simctl", "boot", udid], runner=runner, timeout=45)
            execute(["xcrun", "simctl", "bootstatus", udid, "-b"],
                    runner=runner, timeout=130)
            # A successful targeted bootstatus -b call already confirms
            # that THIS device finished booting. Re-querying the global
            # CoreSimulator device list may hang even after the chosen
            # iPhone is ready (observed in CI run 45001077011).
            # Let the subsequent install/launch step prove usability.
            return udid
        except (SimulatorBootError, json.JSONDecodeError) as error:
            print("Boot failed: %s" % error, file=sys.stderr)
            errors.append("%s: %s" % (udid, error))
    raise SimulatorBootError("all attempts failed: " + "; ".join(errors))


def main():
    try:
        udid = boot_iphone()
    except SimulatorBootError as error:
        sys.exit("iPhone Simulator startup failed: %s\n" % error)
    if os.getenv("GITHUB_ENV"):
        with Path(os.environ["GITHUB_ENV"]).open("a", encoding="utf-8") as file:
            file.write("CM_BOOTED_IPHONE_UDID=%s\n" % udid)
    print(udid)


if __name__ == "__main__":
    main()
