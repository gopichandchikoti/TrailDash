"""Run source, content and native Godot checks; fail on logged engine errors too."""
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def run(command, name):
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace")
    (ROOT / "builds" / f"{name}.log").write_text(result.stdout + result.stderr, encoding="utf-8")
    if result.returncode or re.search(r"(?:SCRIPT ERROR:|ERROR:|instances were leaked)", result.stdout + result.stderr):
        print(result.stdout + result.stderr)
        raise SystemExit(f"FAILED: {name}")
    print(f"PASS: {name}")
    return result.stdout


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    parser.add_argument("--lint-bin", default="", help="Optional directory containing gdlint/gdformat")
    args = parser.parse_args()
    (ROOT / "builds").mkdir(exist_ok=True)

    project = (ROOT / "project.godot").read_text(encoding="utf-8")
    presets = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
    version = re.search(r'config/version="([^"]+)"', project).group(1)
    assert f'version/name="{version}"' in presets, "Export version differs from project version"
    run([sys.executable, "tools/content.py", "--check"], "content")
    run([sys.executable, "-m", "unittest", "discover", "-s", "tests", "-p", "test_*.py"], "release-tests")
    for tool, options in [("gdformat", ["--check", "--line-length", "120"]), ("gdlint", [])]:
        binary = str(Path(args.lint_bin) / tool) if args.lint_bin else shutil.which(tool)
        if args.lint_bin and os.name == "nt":
            binary += ".exe"
        if not binary:
            raise SystemExit("Install requirements-dev.txt or supply --lint-bin")
        run([binary, *options, "scripts", "tests"], tool)
    run([args.godot, "--headless", "--editor", "--path", ".", "--quit"], "import")
    output = run([args.godot, "--headless", "--path", ".", "--script", "tests/test_runner.gd"], "tests")
    print(output.strip())


if __name__ == "__main__":
    main()
