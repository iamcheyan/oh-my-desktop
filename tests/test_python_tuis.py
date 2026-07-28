import importlib.util
import importlib.machinery
import os
import sys
import threading
import time
import unittest


ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EXTENSIONS = os.environ.get(
    "SUMIKA_SHELL_EXTENSIONS_DIR",
    os.path.expanduser("~/.local/share/sumika-shell/extensions"),
)
sys.path.insert(0, os.path.join(ROOT, "bin"))


def load_script(name, relative_path):
    path = relative_path if os.path.isabs(relative_path) else os.path.join(ROOT, relative_path)
    loader = importlib.machinery.SourceFileLoader(name, path)
    spec = importlib.util.spec_from_loader(name, loader)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


S = load_script("sumika_tui_framework_test", "bin/sumika_tui_framework.py")


class SharedRuntimeTests(unittest.TestCase):
    def test_display_width_helpers_preserve_cjk_columns(self):
        self.assertEqual(S.text_width("中A"), 3)
        self.assertLessEqual(S.text_width(S.truncate("中文 text", 5)), 5)
        self.assertEqual(S.text_width(S.pad_to_width("中", 5)), 5)
        self.assertEqual(S.wrapped_lines(["中文ABC"], 4), ["中文", "ABC"])

    def test_unknown_hero_tone_has_a_safe_fallback(self):
        hero = S.hero_line("Voice Input", "Idle", "muted", message="ready")
        self.assertEqual(hero[2], " ready")
        self.assertIsInstance(hero[3], int)

    def test_command_captures_stderr_and_exit_status(self):
        lines, error = S.run_cmd(
            "/bin/sh", "-c", "printf stdout; printf stderr >&2; exit 7"
        )
        self.assertIn("stdoutstderr", "\n".join(lines))
        self.assertEqual(error, "exit 7")

    def test_background_callback_runs_on_main_thread(self):
        main_thread = threading.get_ident()
        called = []
        S.run_cmd_bg(
            "/bin/sh",
            "-c",
            "printf ready",
            callback=lambda lines, error: called.append(
                (threading.get_ident(), lines, error)
            ),
        )
        deadline = time.monotonic() + 2
        while not called and time.monotonic() < deadline:
            S.drain_callbacks()
            time.sleep(0.01)
        self.assertTrue(called)
        self.assertEqual(called[0][0], main_thread)
        self.assertEqual(called[0][1], ["ready"])
        self.assertEqual(called[0][2], "")


class PageRegressionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        keyboard_path = os.path.join(
            EXTENSIONS, "keyboard-remap/bin/sumika-settings-keyboard-tui"
        )
        vm_path = os.path.join(
            EXTENSIONS, "windows-vm/bin/sumika-settings-vm-tui"
        )
        if not os.path.exists(keyboard_path) or not os.path.exists(vm_path):
            raise unittest.SkipTest("canonical Sumika extension binaries are not installed")
        cls.keyboard = load_script(
            "sumika_settings_keyboard_test",
            keyboard_path,
        )
        cls.vm = load_script(
            "sumika_settings_vm_test",
            vm_path,
        )

    def test_keyboard_suffix_removal_is_exact(self):
        model = self.keyboard.Model.__new__(self.keyboard.Model)
        self.assertEqual(model.device_identity("Apple SPI Keyboard"), "apple spi keyboard")
        self.assertEqual(model.device_identity("apple-spi-keyboard"), "apple-spi")
        self.assertEqual(model.device_identity("keybroker"), "keybroker")

    def test_vm_remove_confirmation_is_a_separate_argument(self):
        captured = []
        original = self.vm.S.run_cmd_bg
        self.vm.S.run_cmd_bg = lambda *args, **kwargs: captured.append(args)
        try:
            model = self.vm.Model.__new__(self.vm.Model)
            model.busy = False
            model.message = ""
            model.dirty = False
            model.logs = []
            model.err = ""
            model.run_action("remove", "--yes")
        finally:
            self.vm.S.run_cmd_bg = original
        self.assertEqual(
            captured[0][:3], ("sumika-settings-windows-vm", "remove", "--yes")
        )


if __name__ == "__main__":
    unittest.main()
