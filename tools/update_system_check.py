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
    "class _AndroidUpdateInstallerDialog",
    "Скачать и установить",
    "installApk",
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

windows_url = str(manifest.get("windows_url", ""))
android_url = str(manifest.get("android_url", ""))

windows_filename = windows_url.rsplit("/", 1)[-1]
android_filename = android_url.rsplit("/", 1)[-1]

if not re.fullmatch(
    r"GhostNet-Cyber-VPN-Setup-\d+(?:\.\d+)*-\d+\.exe",
    windows_filename,
):
    raise SystemExit(
        "Updater check failed: Windows URL must point to a "
        "versioned installer, for example "
        "GhostNet-Cyber-VPN-Setup-1.0.6-7.exe"
    )

if not re.fullmatch(
    r"GhostNet-Cyber-VPN-\d+(?:\.\d+)*-\d+\.apk",
    android_filename,
):
    raise SystemExit(
        "Updater check failed: Android URL must point to a "
        "versioned APK, for example "
        "GhostNet-Cyber-VPN-1.0.6-7.apk"
    )

platform_windows = manifest.get("windows")
if isinstance(platform_windows, dict):
    if platform_windows.get("url") != windows_url:
        raise SystemExit(
            "Updater check failed: windows.url does not match windows_url"
        )

platform_android = manifest.get("android")
if isinstance(platform_android, dict):
    if platform_android.get("url") != android_url:
        raise SystemExit(
            "Updater check failed: android.url does not match android_url"
        )

print("Updater contract check passed.")


patch_app_name = (root / "tools" / "patch_app_name.py").read_text(
    encoding="utf-8"
)
for token in (
    "android.permission.REQUEST_INSTALL_PACKAGES",
    ".update_file_provider",
    "ACTION_MANAGE_UNKNOWN_APP_SOURCES",
    "application/vnd.android.package-archive",
):
    if token not in patch_app_name and token not in (root / "tools" / "MainActivity.kt.template").read_text(encoding="utf-8"):
        raise SystemExit(
            f"Updater check failed: Android installer patch missing {token!r}"
        )
