"""Verify the Android artifact's identity, signature, permissions and packaged content."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import zipfile


def command(arguments):
    result = subprocess.run(arguments, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=120)
    if result.returncode:
        raise ValueError(f"APK inspection failed: {Path(arguments[0]).name} (exit {result.returncode})")
    return result.stdout


def parse_manifest(output, version_name, version_code):
    package = re.search(r"^package: name='([^']+)' versionCode='(\d+)' versionName='([^']+)'", output, re.M)
    if not package or package.groups() != ("com.portfolio.traildash", str(version_code), version_name):
        raise ValueError("APK package or version differs from the requested build")
    minimum = re.search(r"^sdkVersion:'(\d+)'", output, re.M)
    target = re.search(r"^targetSdkVersion:'(\d+)'", output, re.M)
    permissions = sorted(re.findall(r"^uses-permission(?:-sdk-\d+)?: name='([^']+)'", output, re.M))
    native = re.search(r"^native-code:(.*)$", output, re.M)
    abis = sorted(re.findall(r"'([^']+)'", native[1])) if native else []
    if not minimum or minimum[1] != "24" or not target or target[1] != "36":
        raise ValueError("APK SDK contract differs from API 24 minimum / API 36 target")
    if permissions != ["android.permission.VIBRATE"] or abis != ["arm64-v8a", "x86_64"]:
        raise ValueError("APK permissions or native architectures differ from the supported contract")
    return {"package": package[1], "versionCode": int(package[2]), "versionName": package[3],
            "minSdk": 24, "targetSdk": 36, "permissions": permissions, "abis": abis}


def verify_launcher(tree):
    aliases = re.finditer(r"^([ ]*)E: activity-alias\b.*?(?=^\1E:|\Z)", tree, re.M | re.S)
    for alias in aliases:
        block = alias[0]
        if all(value in block for value in (
                '="com.godot.game.GodotAppLauncher"', '="com.godot.game.GodotApp"',
                '="android.intent.action.MAIN"', '="android.intent.category.LAUNCHER"')):
            return "com.godot.game.GodotAppLauncher"
    raise ValueError("APK launcher alias or its MAIN/LAUNCHER intent filter is missing")


def verify_content(apk):
    with zipfile.ZipFile(apk) as archive:
        names = archive.namelist()
        forbidden = ("tests", "tools", "docs", "builds", ".github", ".venv")
        if any("/" + folder + "/" in name for name in names for folder in forbidden):
            raise ValueError("Development files were packaged in the APK")
        models = [name for name in names if name.endswith("traildash.model.json")]
        if len(models) != 1:
            raise ValueError("The APK must contain exactly one TrailDash content model")
        model = json.loads(archive.read(models[0]))
        if model.get("schemaVersion") != 1 or model.get("defaultLocale") != "en":
            raise ValueError("Packaged content schema differs from the application contract")
        return len(model["locales"]["en"])


def inspect_apk(apk, sdk, java, expected):
    apk, sdk, java = Path(apk), Path(sdk), Path(java)
    executable = ".exe" if (sdk / "build-tools/36.0.0/aapt.exe").exists() else ""
    tools = sdk / "build-tools/36.0.0"
    manifest = parse_manifest(command([str(tools / ("aapt" + executable)), "dump", "badging", str(apk)]),
                              expected["versionName"], expected["versionCode"])
    manifest["launcher"] = verify_launcher(command([
        str(tools / ("aapt" + executable)), "dump", "xmltree", str(apk), "AndroidManifest.xml"]))
    signature = command([str(java / "bin" / ("java" + executable)), "-jar", str(tools / "lib/apksigner.jar"),
                         "verify", "--verbose", "--print-certs", str(apk)])
    certificate = re.search(r"Signer #1 certificate SHA-256 digest: ([0-9a-fA-F]+)", signature)
    if "Verified using v2 scheme (APK Signature Scheme v2): true" not in signature or not certificate:
        raise ValueError("APK v2 signature verification failed")
    fingerprint = certificate[1].lower()
    if expected.get("certificate") and fingerprint != expected["certificate"].lower().replace(":", ""):
        raise ValueError("APK signing certificate differs from the expected preview identity")
    with apk.open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha256").hexdigest()
    manifest.update({"certificateSha256": fingerprint, "contentKeys": verify_content(apk),
                     "bytes": apk.stat().st_size, "sha256": digest})
    return manifest


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("apk", type=Path)
    parser.add_argument("--sdk", required=True, type=Path)
    parser.add_argument("--java", required=True, type=Path)
    parser.add_argument("--version-name", required=True)
    parser.add_argument("--version-code", required=True, type=int)
    parser.add_argument("--certificate", default="")
    args = parser.parse_args()
    try:
        result = inspect_apk(args.apk, args.sdk, args.java, {
            "versionName": args.version_name, "versionCode": args.version_code, "certificate": args.certificate})
    except (ValueError, OSError, zipfile.BadZipFile) as error:
        raise SystemExit(str(error)) from None
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
