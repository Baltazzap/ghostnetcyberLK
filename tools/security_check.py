from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
main = (root / "lib" / "main.dart").read_text(encoding="utf-8")
pubspec = (root / "pubspec.yaml").read_text(encoding="utf-8")
patch = (root / "tools" / "patch_app_name.py").read_text(encoding="utf-8")

checks = {
    "secure storage dependency": "flutter_secure_storage: 10.3.1" in pubspec,
    "secure storage import": "flutter_secure_storage/flutter_secure_storage.dart" in main,
    "secure token storage": "class AuthTokenStorage" in main,
    "no plaintext token save": "prefs.setString(_tokenKey" not in main,
    "server-only admin role": "baltazzap@gmail.com" not in main and "replaceAll('@', '') == 'baltazzap'" not in main,
    "telegram username is not telegram_id": "'telegram_id': telegram" not in main,
    "API timeout": "Duration(seconds: 15)" in main and "request.timeout(_requestTimeout)" in main,
    "HTTPS API": "const String apiBaseUrl = 'https://" in main,
    "cleartext disabled": 'android:usesCleartextTraffic="false"' in patch,
    "Android backup disabled": 'android:allowBackup="false"' in patch,
    "minimum Android SDK 23": "minSdk = 23" in patch and "minSdkVersion 23" in patch,
}

failed = [name for name, passed in checks.items() if not passed]
for name, passed in checks.items():
    print(f"[{'OK' if passed else 'FAIL'}] {name}")

if failed:
    print("\nSecurity check failed:", ", ".join(failed))
    sys.exit(1)

print("\nSecurity patch verification passed.")
