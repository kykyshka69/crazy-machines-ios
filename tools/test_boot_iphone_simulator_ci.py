"""Boot helper regression tests requiring no Apple SDK or simulator."""
import json
import subprocess
import unittest

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

    def test_no_phones_is_explicit_error(self):
        runner = FakeSimulator(make_devices(("iPad", "ipad", "Shutdown", True)))
        with self.assertRaisesRegex(SimulatorBootError, "no available iPhone"):
            boot_iphone(runner=runner)

    def test_subprocess_timeout_is_bounded_error(self):
        def slow(argv, **kwargs):
            raise subprocess.TimeoutExpired(argv, timeout=kwargs["timeout"])
        with self.assertRaisesRegex(SimulatorBootError, "timeout"):
            execute(["xcrun", "simctl", "bootstatus", "x", "-b"],
                    runner=slow, timeout=12)


if __name__ == "__main__":
    unittest.main()
