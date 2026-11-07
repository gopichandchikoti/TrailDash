"""Focused checks for the version, export configuration and Android artifact boundary."""
import os
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from build_android import EPOCH, SIGNING_KEYS, preview_code, set_option, signing_identity
from verify_apk import parse_manifest, verify_launcher

MANIFEST = """package: name='com.portfolio.traildash' versionCode='123' versionName='0.1.0-preview.123'
sdkVersion:'24'
targetSdkVersion:'36'
uses-permission: name='android.permission.VIBRATE'
launchable-activity: name='com.godot.game.GodotAppLauncher'
native-code: 'arm64-v8a' 'x86_64'
"""


class ReleaseChecks(unittest.TestCase):
    def test_version_code_is_independent_of_workflow_run_numbers(self):
        self.assertEqual(preview_code(EPOCH + 123), 123)
        self.assertGreater(preview_code(EPOCH + 124), preview_code(EPOCH + 123))
        for timestamp in (EPOCH, EPOCH + 2100000000):
            with self.assertRaises(ValueError):
                preview_code(timestamp)

    def test_export_settings_keep_literal_characters(self):
        original = '[preset.0.options]\nversion/code=1\nversion/name="0.1.0"\n'
        updated = set_option(original, "version/code", 123)
        updated = set_option(updated, "keystore/debug_password", 'literal$\\"value')
        self.assertIn('version/code=123\n', updated)
        self.assertIn('keystore/debug_password="literal$\\\\\\"value"', updated)
        self.assertIn('version/name="0.1.0"', updated)

    def test_partial_signing_configuration_is_rejected(self):
        values = {key: "" for key in SIGNING_KEYS}
        values[SIGNING_KEYS[0]] = "incomplete"
        with patch.dict(os.environ, values), self.assertRaises(ValueError):
            signing_identity(Path("unused"), Path("unused"), True)

    def test_missing_publish_key_fails_before_creating_an_ephemeral_key(self):
        with patch.dict(os.environ, {key: "" for key in SIGNING_KEYS}), self.assertRaises(ValueError):
            signing_identity(Path("unused"), Path("unused"), True)

    def test_android_contract(self):
        result = parse_manifest(MANIFEST, "0.1.0-preview.123", 123)
        self.assertEqual(result["minSdk"], 24)
        self.assertEqual(result["abis"], ["arm64-v8a", "x86_64"])

    def test_wrong_version_is_rejected(self):
        with self.assertRaises(ValueError):
            parse_manifest(MANIFEST, "0.1.0-preview.124", 124)

    def test_launcher_alias_must_have_both_intent_entries(self):
        alias = '''      E: activity-alias (line=49)
        A: android:name="com.godot.game.GodotAppLauncher"
        A: android:targetActivity="com.godot.game.GodotApp"
          A: android:name="android.intent.action.MAIN"
          A: android:name="android.intent.category.LAUNCHER"
      E: meta-data (line=62)
'''
        self.assertEqual(verify_launcher(alias), "com.godot.game.GodotAppLauncher")
        with self.assertRaises(ValueError):
            verify_launcher(alias.replace('="android.intent.category.LAUNCHER"', ""))

    def test_extra_permission_or_missing_architecture_is_rejected(self):
        for badging in (MANIFEST + "uses-permission: name='android.permission.INTERNET'\n",
                        MANIFEST.replace(" 'x86_64'", ""), MANIFEST.replace("sdkVersion:'24'", "sdkVersion:'23'")):
            with self.assertRaises(ValueError):
                parse_manifest(badging, "0.1.0-preview.123", 123)


if __name__ == "__main__":
    unittest.main()
