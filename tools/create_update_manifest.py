from __future__ import annotations

import argparse
import hashlib
import json
import re
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PUBSPEC = ROOT / "pubspec.yaml"
BASE_URL = "https://ghostnetcyber.ru/downloads"


def read_version() -> tuple[str, int]:
    text = PUBSPEC.read_text(encoding="utf-8")
    match = re.search(
        r"^version:\s*([0-9]+(?:\.[0-9]+)*)\+([0-9]+)\s*$",
        text,
        flags=re.MULTILINE,
    )

    if not match:
        raise SystemExit("Не удалось прочитать version из pubspec.yaml")

    return match.group(1), int(match.group(2))


def file_metadata(path: str | None) -> dict[str, object]:
    if not path:
        return {}

    file_path = Path(path)
    if not file_path.exists():
        raise SystemExit(f"Файл релиза не найден: {file_path}")

    digest = hashlib.sha256(file_path.read_bytes()).hexdigest()
    return {
        "sha256": digest,
        "size": file_path.stat().st_size,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--output",
        default="release/version.json",
    )
    parser.add_argument(
        "--mandatory",
        action="store_true",
    )
    parser.add_argument(
        "--title",
        default="Доступно обновление GhostNet Cyber VPN",
    )
    parser.add_argument(
        "--message",
        default=(
            "На Android обновление скачивается прямо внутри GhostNet, "
            "после чего приложение запускает системный установщик."
        ),
    )
    parser.add_argument("--android-file")
    parser.add_argument("--windows-file")
    args = parser.parse_args()

    version, build = read_version()
    release_id = f"{version}-{build}"

    android_filename = (
        f"GhostNet-Cyber-VPN-{release_id}.apk"
    )
    windows_filename = (
        f"GhostNet-Cyber-VPN-Setup-{release_id}.exe"
    )

    android_url = f"{BASE_URL}/{android_filename}"
    windows_url = f"{BASE_URL}/{windows_filename}"

    android = {
        "version": version,
        "build": build,
        "url": android_url,
        "filename": android_filename,
        **file_metadata(args.android_file),
    }
    windows = {
        "version": version,
        "build": build,
        "url": windows_url,
        "filename": windows_filename,
        **file_metadata(args.windows_file),
    }

    payload = {
        "schema": 2,
        "release_id": release_id,
        "version": version,
        "build": build,
        "mandatory": bool(args.mandatory),
        "title": args.title,
        "message": args.message,
        "published_at": datetime.now(timezone.utc).strftime(
            "%d.%m.%Y"
        ),
        # Старые версии приложения продолжают читать эти поля.
        "android_url": android_url,
        "windows_url": windows_url,
        # Новые версии используют платформенные блоки.
        "android": android,
        "windows": windows,
    }

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    print(f"Update manifest created: {output}")
    print(f"Release: {version}+{build}")
    print(f"Android URL: {android_url}")
    print(f"Windows URL: {windows_url}")


if __name__ == "__main__":
    main()
