"""Export and verify a local APK or a reproducible CI preview bundle without retaining signing data."""
import argparse
import base64
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

from verify_apk import inspect_apk

ROOT = Path(__file__).resolve().parents[1]
EPOCH = 1704067200  # 2024-01-01 UTC; independent of a workflow filename or run counter.
SIGNING_KEYS = ("ANDROID_PREVIEW_KEYSTORE_BASE64", "ANDROID_PREVIEW_KEYSTORE_PASSWORD",
                "ANDROID_PREVIEW_KEY_ALIAS", "ANDROID_PREVIEW_KEY_PASSWORD")


def project_version():
    source = (ROOT / "project.godot").read_text(encoding="utf-8")
    match = re.search(r'^config/version="(\d+\.\d+\.\d+)"$', source, re.M)
    if not match:
        raise ValueError("project.godot must declare one semantic application version")
    return match[1]


def preview_code(timestamp):
    code = int(timestamp) - EPOCH
    if not 1 < code < 2100000000:
        raise ValueError("Preview versionCode is outside Android's supported range")
    return code


def set_option(source, key, value):
    line = key + "=" + (str(value) if isinstance(value, int) else json.dumps(str(value)))
    expression = r"^" + re.escape(key) + r"=.*$"
    if re.search(expression, source, re.M):
        return re.sub(expression, lambda _: line, source, count=1, flags=re.M)
    return source.rstrip() + "\n" + line + "\n"


def signing_identity(directory, java, required):
    values = [os.environ.get(key, "") for key in SIGNING_KEYS]
    if any(values) and not all(values):
        raise ValueError("All four ANDROID_PREVIEW signing secrets must be configured together")
    keystore = directory / "preview.keystore"
    if all(values):
        keystore.write_bytes(base64.b64decode(values[0], validate=True))
        keystore.chmod(0o600)
        return {"path": keystore.as_posix(), "storePassword": values[1], "alias": values[2],
                "keyPassword": values[3], "mode": "stable preview key"}
    if required:
        raise ValueError("Publishing requires the configured stable preview signing key; the previous download is preserved")
    extension = ".exe" if os.name == "nt" else ""
    result = subprocess.run([str(java / "bin" / ("keytool" + extension)), "-genkeypair", "-noprompt",
                             "-keystore", str(keystore), "-storepass", "android", "-keypass", "android",
                             "-alias", "androiddebugkey", "-keyalg", "RSA", "-keysize", "2048",
                             "-validity", "10000", "-dname", "CN=TrailDash PR preview"], capture_output=True, timeout=60)
    if result.returncode:
        raise ValueError("Could not generate an isolated review-only debug signing key")
    return {"path": keystore.as_posix(), "storePassword": "android", "alias": "androiddebugkey",
            "keyPassword": "android", "mode": "ephemeral review key"}


def configure_editor(path, sdk, java):
    path.parent.mkdir(parents=True, exist_ok=True)
    settings = '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
    settings += "export/android/android_sdk_path = " + json.dumps(sdk.as_posix()) + "\n"
    settings += "export/android/java_sdk_path = " + json.dumps(java.as_posix()) + "\n"
    path.write_text(settings, encoding="utf-8", newline="\n")


def export_apk(godot, apk, options):
    presets = ROOT / "export_presets.cfg"
    original = presets.read_bytes()
    updated = original.decode("utf-8")
    for key, value in options.items():
        updated = set_option(updated, key, value)
    try:
        presets.write_text(updated, encoding="utf-8", newline="\n")
        result = subprocess.run([godot, "--headless", "--path", str(ROOT), "--export-debug", "Android", str(apk)],
                                cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=900)
        log = result.stdout + result.stderr
        for key in SIGNING_KEYS:
            secret = os.environ.get(key, "")
            if secret:
                log = log.replace(secret, "<REDACTED>")
        (ROOT / "builds/export.log").write_text(log, encoding="utf-8")
        if result.returncode or re.search(r"SCRIPT ERROR:|ERROR:", log):
            raise ValueError("Android export failed; see builds/export.log (signing values are redacted)")
    finally:
        presets.write_bytes(original)


def build(args):
    sdk, java = args.sdk.resolve(), args.java.resolve()
    if not args.godot or not sdk.is_dir() or not java.is_dir():
        raise ValueError("Set GODOT_BIN, ANDROID_HOME and JAVA_HOME to the installed toolchain")
    base = project_version()
    code = args.version_code if args.version_code is not None else preview_code(datetime.now(timezone.utc).timestamp())
    if not 0 < code < 2100000000:
        raise ValueError("versionCode must be a positive Android version code below 2100000000")
    name = base + "-preview." + str(code) if args.ci else base
    output = args.output.resolve() if args.output else ROOT / "builds" / (
        "release/TrailDash-preview.apk" if args.ci else f"traildash-{base}-debug.apk")
    output.parent.mkdir(parents=True, exist_ok=True)
    (ROOT / "builds").mkdir(exist_ok=True)
    if args.editor_settings:
        configure_editor(args.editor_settings, sdk, java)
    with tempfile.TemporaryDirectory(prefix="traildash-signing-", dir=os.environ.get("RUNNER_TEMP")) as temporary:
        options = {"version/code": code, "version/name": name}
        signing = None
        if args.ci:
            required = os.environ.get("TRAILDASH_PUBLISHABLE") == "true"
            signing = signing_identity(Path(temporary), java, required)
            options.update({"keystore/debug": signing["path"], "keystore/debug_user": signing["alias"],
                            "keystore/debug_password": signing["storePassword"]})
            if signing["keyPassword"] != signing["storePassword"]:
                raise ValueError("Godot's debug keystore requires the key password to match the store password")
        export_apk(args.godot, output, options)
    expected = {"versionName": name, "versionCode": code, "certificate": os.environ.get("TRAILDASH_PREVIEW_CERT_SHA256", "")}
    evidence = inspect_apk(output, sdk, java, expected)
    commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    evidence.update({"sourceVersion": base, "commit": commit, "signing": signing["mode"] if signing else "local debug key",
                     "builtAt": datetime.now(timezone.utc).isoformat(), "workflowRun": os.environ.get("GITHUB_RUN_ID", "local")})
    output.with_suffix(output.suffix + ".sha256").write_text(evidence["sha256"] + "  " + output.name + "\n", encoding="utf-8")
    if args.ci:
        (output.parent / "build-evidence.json").write_text(json.dumps(evidence, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"apk": str(output), "versionName": name, "versionCode": code,
                      "sha256": evidence["sha256"], "signing": evidence["signing"]}, indent=2))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", ""))
    parser.add_argument("--sdk", type=Path, default=os.environ.get("ANDROID_HOME", ""))
    parser.add_argument("--java", type=Path, default=os.environ.get("JAVA_HOME", ""))
    parser.add_argument("--ci", action="store_true")
    parser.add_argument("--version-code", type=int)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--editor-settings", type=Path)
    args = parser.parse_args()
    try:
        build(args)
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        raise SystemExit(str(error)) from None


if __name__ == "__main__":
    main()
