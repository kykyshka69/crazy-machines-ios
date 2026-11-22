"""Boot helper regression tests requiring no Apple SDK or simulator."""
import json
import os
import subprocess
import sys
import time
import unittest
from unittest.mock import patch

from boot_iphone_simulator_ci import (
    SimulatorBootError, boot_iphone, execute, iphone_candidates,
)


def make_devices(*items):
    return json.dumps({"devices": {"com.apple.CoreSimulator.SimRuntime.iOS-27-0": [
        {"name": name, "udid": udid, "state": state, "isAvailable": available}
        for name, udid, state, available in items
    ]}})


class FakeSimulator:
    def __init__(self, source, fail_bootstatus=()):
        self.source = source
        self.fail = set(fail_bootstatus)
        self.booted = set()
        self.calls = []
        for item in json.loads(source)["devices"].values():
            for device in item:
                if device["state"] == "Booted":
                    self.booted.add(device["udid"])

    def __call__(self, argv, **kwargs):
        self.calls.append((argv, kwargs.get("timeout")))
        action = argv[2]
        if action == "list":
            if argv[4] == "available":
                return subprocess.CompletedProcess(argv, 0, self.source, "")
            data = json.loads(self.source)
            for devices in data["devices"].values():
                for device in devices:
                    device["state"] = "Booted" if device["udid"] in self.booted else "Shutdown"
            return subprocess.CompletedProcess(argv, 0, json.dumps(data), "")
        if action == "boot":
            self.booted.add(argv[3])
        if action == "bootstatus" and argv[3] in self.fail:
            raise subprocess.TimeoutExpired(argv, timeout=kwargs["timeout"])
        return subprocess.CompletedProcess(argv, 0, "", "")


class SimulatorCIRegression(unittest.TestCase):
    def test_booted_phone_precedes_shutdown_phone(self):
        data = make_devices(("iPhone 16", "shut", "Shutdown", True),
                            ("iPhone 17", "booted", "Booted", True))
        self.assertEqual(iphone_candidates(json.loads(data))[0][0], "booted")

    def test_unavailable_and_non_phone_devices_rejected(self):
        data = make_devices(("iPhone 16", "unavail", "Shutdown", False),
                            ("iPad Pro", "pad", "Booted", True),
                            ("iPhone 17", "good", "Shutdown", True))
        self.assertEqual([x[0] for x in iphone_candidates(json.loads(data))], ["good"])

    def test_invalid_devices_json(self):
        with self.assertRaises(SimulatorBootError):
            iphone_candidates({"unexpected": []})

    def test_reuses_running_iphone_without_booting(self):
        runner = FakeSimulator(make_devices(("iPhone 17", "live", "Booted", True)))
        self.assertEqual(boot_iphone(runner=runner), "live")
        self.assertFalse(any(call[0][2] == "boot" for call in runner.calls))

    def test_boots_shutdown_iphone_with_bounded_status(self):
        runner = FakeSimulator(make_devices(("iPhone 17", "new", "Shutdown", True)))
        self.assertEqual(boot_iphone(runner=runner), "new")
        self.assertIn((["xcrun", "simctl", "bootstatus", "new", "-b"], 130),
                      runner.calls)

    def test_does_not_query_global_booted_list_after_ready(self):
        # The shared CoreSimulator list command can hang even though the
        # selected iPhone's targeted bootstatus has already succeeded.
        class BrokenGlobalList(FakeSimulator):
            def __call__(self, argv, **kwargs):
                if argv[2:] == ["list", "devices", "booted", "-j"]:
                    raise subprocess.TimeoutExpired(argv, timeout=kwargs["timeout"])
                return super().__call__(argv, **kwargs)
        runner = BrokenGlobalList(make_devices(
            ("iPhone 17 Pro", "ready", "Shutdown", True)
        ))
        self.assertEqual(boot_iphone(runner=runner), "ready")
        self.assertFalse(any(
            command[2:] == ["list", "devices", "booted", "-j"]
            for command, _ in runner.calls
        ))

    def test_timeout_tries_second_phone(self):
        runner = FakeSimulator(make_devices(("iPhone 17", "a", "Shutdown", True),
                                             ("iPhone 18", "b", "Shutdown", True)),
                               fail_bootstatus={"a"})
        self.assertEqual(boot_iphone(runner=runner), "b")
        self.assertEqual(len([x for x, _ in runner.calls if x[2] == "bootstatus"]), 2)

    def test_all_boot_attempts_timeout_cleanly(self):
        runner = FakeSimulator(make_devices(("iPhone 17", "a", "Shutdown", True),
                                             ("iPhone 18", "b", "Shutdown", True)),
                               fail_bootstatus={"a", "b"})
        with self.assertRaisesRegex(SimulatorBootError, "all attempts failed"):
            boot_iphone(runner=runner)

    def test_private_capture_honors_requested_device(self):
        runner = FakeSimulator(make_devices(("iPhone 17", "first", "Booted", True),
                                             ("iPhone 18", "chosen", "Shutdown", True)))
        self.assertEqual(boot_iphone(runner=runner, preferred_udid="chosen"), "chosen")

    def test_private_capture_rejects_missing_device(self):
        runner = FakeSimulator(make_devices(("iPhone 17", "other", "Booted", True)))
        with self.assertRaisesRegex(SimulatorBootError, "requested iPhone"):
            boot_iphone(runner=runner, preferred_udid="missing")

    def test_prefers_recent_verified_iphone_without_displacing_booted(self):
        # The macOS CI runner exposes iPhone 16e, 17 and 17 Pro in
        # alphabetical order. A specified preferred model should be tried
        # first; an already booted phone still wins to avoid extra boots.
        runner = FakeSimulator(make_devices(
            ("iPhone 16e", "slow", "Shutdown", True),
            ("iPhone 17 Pro", "preferred", "Shutdown", True)
        ))
        with patch.dict(os.environ, {"CM_SIMULATOR_PREFERRED_NAME": "iPhone 17 Pro"}):
            self.assertEqual(boot_iphone(runner=runner), "preferred")
        boot_calls = [argv[3] for argv, _ in runner.calls if argv[2] == "boot"]
        self.assertEqual(boot_calls, ["preferred"])

        booted = FakeSimulator(make_devices(
            ("iPhone 16e", "already", "Booted", True),
            ("iPhone 17 Pro", "preferred", "Shutdown", True)
        ))
        with patch.dict(os.environ, {"CM_SIMULATOR_PREFERRED_NAME": "iPhone 17 Pro"}):
            self.assertEqual(boot_iphone(runner=booted), "already")
        self.assertFalse(any(argv[2] == "boot" for argv, _ in booted.calls))

    def test_no_phones_is_explicit_error(self):
        runner = FakeSimulator(make_devices(("iPad", "ipad", "Shutdown", True)))
        with self.assertRaisesRegex(SimulatorBootError, "no available iPhone"):
            boot_iphone(runner=runner)

    def test_real_process_group_timeout_kills_inherited_pipe_children(self):
        # A child that inherits captured stdout used to keep
        # subprocess.run().communicate() blocked even after xcrun died.
        # This regression is runnable on Linux and macOS, with no Xcode.
        started = time.monotonic()
        with self.assertRaisesRegex(SimulatorBootError, "timeout"):
            execute([
                sys.executable, "-c",
                "import subprocess,sys,time; "
                "subprocess.Popen([sys.executable,'-c','import time; time.sleep(30)']); "
                "time.sleep(30)"
            ], timeout=0.25)
        self.assertLess(time.monotonic() - started, 6,
                        "A simulator child process held the job pipes open")

    def test_subprocess_timeout_is_bounded_error(self):
        def slow(argv, **kwargs):
            raise subprocess.TimeoutExpired(argv, timeout=kwargs["timeout"])
        with self.assertRaisesRegex(SimulatorBootError, "timeout"):
            execute(["xcrun", "simctl", "bootstatus", "x", "-b"],
                    runner=slow, timeout=12)


if __name__ == "__main__":
    unittest.main()
