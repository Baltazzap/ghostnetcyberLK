from pathlib import Path
import re

APP_NAME = "GhostNet Cyber VPN"
EXE_NAME = "GhostNetCyberVPN"

root = Path(__file__).resolve().parents[1]

main_cpp = root / "windows" / "runner" / "main.cpp"
cmake = root / "windows" / "CMakeLists.txt"

# 1) Заголовок окна Windows.
# В разных версиях Flutter встречается:
# window.Create(L"...", ...)
# или
# window.CreateAndShow(L"...", ...)
if main_cpp.exists():
    text = main_cpp.read_text(encoding="utf-8", errors="ignore")

    text = re.sub(
        r'window\.CreateAndShow\(\s*L"[^"]+"\s*,',
        f'window.CreateAndShow(L"{APP_NAME}",',
        text,
    )

    text = re.sub(
        r'window\.Create\(\s*L"[^"]+"\s*,',
        f'window.Create(L"{APP_NAME}",',
        text,
    )

    # Дополнительная страховка, если где-то осталось техническое имя проекта.
    text = text.replace('L"ghostnet_cyber_vpn"', f'L"{APP_NAME}"')
    text = text.replace('L"ghost_net_cyber_vpn"', f'L"{APP_NAME}"')

    main_cpp.write_text(text, encoding="utf-8")

# 2) Имя EXE без подчёркиваний + фикс CMake 4 для Firebase C++ SDK.
if cmake.exists():
    text = cmake.read_text(encoding="utf-8", errors="ignore")

    text = re.sub(
        r'set\(BINARY_NAME\s+"[^"]+"\)',
        f'set(BINARY_NAME "{EXE_NAME}")',
        text,
    )

    text = re.sub(
        r'set\(APPLICATION_ID\s+"[^"]+"\)',
        'set(APPLICATION_ID "ru.ghostnet.cybervpn")',
        text,
    )

    # GitHub Actions windows-latest может использовать CMake 4.x.
    # Firebase C++ SDK внутри firebase_core пока содержит cmake_minimum_required ниже 3.5,
    # из-за этого сборка Windows падает на check/generate build files.
    # Ставим совместимость на уровне корневого CMake-проекта до подключения плагинов.
    if "CMAKE_POLICY_VERSION_MINIMUM" not in text:
        text = re.sub(
            r'(cmake_minimum_required\(VERSION[^\n]+\)\s*)',
            r'\1\nset(CMAKE_POLICY_VERSION_MINIMUM 3.5 CACHE STRING "Allow Firebase C++ SDK old CMake policy version" FORCE)\n',
            text,
            count=1,
        )

    cmake.write_text(text, encoding="utf-8")

print(f"Windows title fixed: {APP_NAME}")
print(f"Windows EXE fixed: {EXE_NAME}.exe")
