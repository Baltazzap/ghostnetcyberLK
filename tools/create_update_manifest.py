from __future__ import annotations

import argparse
import json
import re
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PUBSPEC = ROOT / "pubspec.yaml"


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
            "Установите новую версию приложения. "
            "В обновлении улучшены стабильность и безопасность."
        ),
    )
    args = parser.parse_args()

    version, build = read_version()
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)

    payload = {
        "version": version,
        "build": build,
        "mandatory": bool(args.mandatory),
        "title": args.title,
        "message": args.message,
        "published_at": datetime.now(timezone.utc).strftime("%d.%m.%Y"),
        "android_url": (
            "https://ghostnetcyber.ru/downloads/"
            "GhostNet-Cyber-VPN.apk"
        ),
        "windows_url": (
            "https://ghostnetcyber.ru/downloads/"
            "GhostNet-Cyber-VPN-Windows.zip"
        ),
    }

    output.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    print(f"Update manifest created: {output}")
    print(f"Release: {version}+{build}")


if __name__ == "__main__":
    main()
