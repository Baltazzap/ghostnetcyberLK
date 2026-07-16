from __future__ import annotations

import os
import re
import shutil
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PUBSPEC = ROOT / "pubspec.yaml"
SCRIPT = ROOT / "installer" / "ghostnet_windows.iss"
RELEASE_EXE = (
    ROOT
    / "build"
    / "windows"
    / "x64"
    / "runner"
    / "Release"
    / "GhostNetCyberVPN.exe"
)
OUTPUT = ROOT / "release" / "GhostNet-Cyber-VPN-Setup.exe"


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


def find_iscc() -> Path:
    names = ("ISCC.exe", "iscc.exe", "iscc")
    for name in names:
        resolved = shutil.which(name)
        if resolved:
            return Path(resolved)

    env_paths = [
        os.environ.get("ProgramFiles(x86)"),
        os.environ.get("ProgramFiles"),
        os.environ.get("LOCALAPPDATA"),
        os.environ.get("ChocolateyInstall"),
    ]

    candidates: list[Path] = []
    if env_paths[0]:
        candidates.append(Path(env_paths[0]) / "Inno Setup 6" / "ISCC.exe")
    if env_paths[1]:
        candidates.append(Path(env_paths[1]) / "Inno Setup 6" / "ISCC.exe")
    if env_paths[2]:
        candidates.append(
            Path(env_paths[2])
            / "Programs"
            / "Inno Setup 6"
            / "ISCC.exe"
        )
    if env_paths[3]:
        candidates.append(Path(env_paths[3]) / "bin" / "ISCC.exe")

    for candidate in candidates:
        if candidate.exists():
            return candidate

    raise SystemExit(
        "ISCC.exe не найден. Установите Inno Setup 6 "
        "или используйте GitHub Actions windows-2022."
    )


def main() -> None:
    if not RELEASE_EXE.exists():
        raise SystemExit(
            "Сначала соберите Windows-приложение: "
            "flutter build windows --release"
        )

    version, build = read_version()
    iscc = find_iscc()

    (ROOT / "release").mkdir(parents=True, exist_ok=True)

    command = [
        str(iscc),
        "/Qp",
        f"/DAppVersion={version}",
        f"/DAppBuild={build}",
        str(SCRIPT),
    ]

    print(f"Inno Setup compiler: {iscc}")
    print(f"Building installer for {version}+{build}")

    result = subprocess.run(
        command,
        cwd=ROOT,
        check=False,
    )
    if result.returncode != 0:
        raise SystemExit(
            f"Inno Setup compilation failed with code "
            f"{result.returncode}"
        )

    if not OUTPUT.exists():
        raise SystemExit(f"Installer was not created: {OUTPUT}")

    print(f"Installer created: {OUTPUT}")
    print(f"Installer size: {OUTPUT.stat().st_size} bytes")


if __name__ == "__main__":
    main()
