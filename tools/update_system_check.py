from pathlib import Path
import json
import re

root = Path(__file__).resolve().parents[1]
main = (root / "lib" / "main.dart").read_text(encoding="utf-8")
pubspec = (root / "pubspec.yaml").read_text(encoding="utf-8")
manifest_path = root / "website_update_files" / "downloads" / "version.json"

required_main_tokens = [
    "class AppUpdateService",
    "PackageInfo.fromPlatform()",
    "https://ghostnetcyber.ru/downloads/version.json",
    "Проверить обновления",
    "_scheduleUpdateCheck();",
]

for token in required_main_tokens:
    if token not in main:
        raise SystemExit(f"Updater check failed: missing {token!r}")

if "package_info_plus:" not in pubspec:
    raise SystemExit("Updater check failed: package_info_plus is missing")

version_match = re.search(
    r"^version:\s*([0-9]+(?:\.[0-9]+)*)\+([0-9]+)\s*$",
    pubspec,
    flags=re.MULTILINE,
)
if not version_match:
    raise SystemExit("Updater check failed: invalid pubspec version")

manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
if manifest["version"] != version_match.group(1):
    raise SystemExit("Updater check failed: manifest version mismatch")
if int(manifest["build"]) != int(version_match.group(2)):
    raise SystemExit("Updater check failed: manifest build mismatch")

for key in ("android_url", "windows_url"):
    if not str(manifest.get(key, "")).startswith("https://"):
        raise SystemExit(f"Updater check failed: invalid {key}")

if not str(manifest["windows_url"]).endswith(
    "GhostNet-Cyber-VPN-Setup.exe"
):
    raise SystemExit(
        "Updater check failed: Windows URL must point to installer"
    )

print("Updater contract check passed.")
