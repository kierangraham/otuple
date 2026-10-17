import subprocess
import io
import json
import sys
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

from backend import TupleCli, contacts_from_json, contacts_from_text, validate_link, serve


class BackendTests(unittest.TestCase):
    def test_legacy_contact_names_presence_and_favorites(self):
        result = contacts_from_text("  42 Alex Morgan <alex@example.com> [available] (favorite)\n  9 Taylor Brooks <taylor@example.com> [in call]\n  5 Sam Rivera <sam@example.com> [unavailable]\n")
        self.assertEqual(result[0], dict(id="42", name="Alex Morgan", email="alex@example.com", status="online", favorite=True))
        self.assertEqual([r["status"] for r in result], ["online", "busy", "offline"])

    def test_unknown_output_does_not_become_empty_contacts(self):
        with self.assertRaises(ValueError):
            contacts_from_text("You must sign in first")
        self.assertEqual(contacts_from_text("\n"), [])

    def test_json_normalization(self):
        result = contacts_from_json({"contacts": [{"id": 42, "full_name": "Jamie Chen", "email": "jamie@example.com", "presence": "available", "favorited": True}]})
        self.assertEqual(result[0]["id"], "42")
        self.assertEqual(result[0]["status"], "online")
        self.assertTrue(result[0]["favorite"])

    def test_call_links(self):
        self.assertEqual(validate_link("https://tuple.app/call/123"), "https://tuple.app/call/123")
        for value in ["http://tuple.app/call/123", "https://tuple.app.evil.example/x", "https://evil.example/x", "https://user:password@tuple.app/x", "--help"]:
            with self.subTest(value=value), self.assertRaises(ValueError):
                validate_link(value)

    def cli(self, modern=False):
        cli = TupleCli.__new__(TupleCli)
        cli.binary = "tuple"
        cli.modern = modern
        cli.version = "test"
        return cli

    def test_legacy_call_uses_numeric_user_id(self):
        cli = self.cli()
        with patch.object(cli, "run", return_value="") as run:
            cli.action("call", "42")
            run.assert_called_once_with(["call", "42"], timeout=40)
            for value in ["Alex Morgan", "--help", "42; touch /tmp/unsafe"]:
                with self.assertRaises(ValueError):
                    cli.action("call", value)

    def test_modern_call_uses_documented_command(self):
        cli = self.cli(modern=True)
        with patch.object(cli, "run", return_value={}) as run:
            cli.action("call", "42")
            run.assert_called_once_with(["call", "start", "42"], timeout=40)

    def test_json_errors_are_reported(self):
        cli = self.cli(modern=True)
        with patch.object(cli, "run_raw", return_value=subprocess.CompletedProcess([], 1, "", '{"error":"not in a call"}')):
            with self.assertRaisesRegex(RuntimeError, "not in a call"):
                cli.run(["call", "mute"])

    def test_setting_values_are_validated(self):
        cli = self.cli()
        with patch.object(cli, "run", return_value="") as run:
            cli.action("start-muted", "1")
            run.assert_called_once_with(["set", "start-calls-muted", "1"], timeout=40)
            with self.assertRaises(ValueError):
                cli.action("overlay", "invalid")

    def test_unsupported_actions_are_rejected(self):
        with self.assertRaises(ValueError):
            self.cli().action("anything", "")

    def test_demo_stream_runs_without_tray_and_exits_at_eof(self):
        result = subprocess.run([sys.executable, "backend.py", "--demo"], input="", capture_output=True, text=True, timeout=5, check=True)
        snapshot = json.loads(result.stdout)
        self.assertEqual(snapshot["type"], "snapshot")
        self.assertEqual(len(snapshot["contacts"]), 4)
        self.assertEqual(snapshot["version"], "Demo")

    def test_offline_pauses_polling_until_online(self):
        cli = Mock(version="test")
        cli.action.return_value = ""
        cli.snapshot.return_value = dict(type="snapshot", contacts=[], state={}, settings={}, modern=False, version="test")
        commands = '\n'.join(json.dumps(dict(action=action)) for action in ["off", "refresh", "on"]) + '\n'
        with patch("backend.TupleCli", return_value=cli), patch("sys.stdin", io.StringIO(commands)), patch("sys.stdout", io.StringIO()), patch("signal.signal"):
            serve()
        self.assertEqual(cli.snapshot.call_count, 2)
        self.assertEqual([call.args[0] for call in cli.action.call_args_list], ["off", "on"])


class ManifestTests(unittest.TestCase):
    def test_root_manifest_entry_points_and_backend_path(self):
        root = Path(__file__).resolve().parent.parent
        manifest = json.loads((root / "manifest.json").read_text())
        self.assertEqual(manifest["id"], "kierangraham.otuple")
        for entry in manifest["entryPoints"].values():
            self.assertTrue((root / entry).is_file(), entry)
        service = root / manifest["entryPoints"]["service"]
        self.assertIn('Qt.resolvedUrl("../backend.py")', service.read_text())
        self.assertTrue((service.parent / "../backend.py").resolve().is_file())


if __name__ == "__main__":
    unittest.main()
