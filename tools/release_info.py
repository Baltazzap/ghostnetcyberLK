from __future__ import annotations

import argparse
import re
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
        "--field",
        choices=[
            "version",
            "build",
            "release-id",
            "android-filename",
            "windows-filename",
        ],
        required=True,
    )
    args = parser.parse_args()

    version, build = read_version()
    release_id = f"{version}-{build}"

    values = {
        "version": version,
        "build": str(build),
        "release-id": release_id,
        "android-filename": (
            f"GhostNet-Cyber-VPN-{release_id}.apk"
        ),
        "windows-filename": (
            f"GhostNet-Cyber-VPN-Setup-{release_id}.exe"
        ),
    }

    print(values[args.field])


if __name__ == "__main__":
    main()
