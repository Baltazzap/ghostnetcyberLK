from pathlib import Path
import re

APP_NAME = "GhostNet Cyber VPN"
EXE_NAME = "GhostNetCyberVPN"

root = Path(__file__).resolve().parents[1]

main_cpp = root / "windows" / "runner" / "main.cpp"
cmake = root / "windows" / "CMakeLists.txt"

SINGLE_INSTANCE_HELPERS = r"""
// GHOSTNET_SINGLE_INSTANCE_HELPERS_BEGIN
namespace {

constexpr wchar_t kGhostNetSingleInstanceMutex[] =
    L"Local\\GhostNetCyberVPN.SingleInstance";
constexpr wchar_t kGhostNetWindowTitle[] = L"GhostNet Cyber VPN";

class ScopedWindowsHandle {
 public:
  explicit ScopedWindowsHandle(HANDLE handle) : handle_(handle) {}

  ScopedWindowsHandle(const ScopedWindowsHandle&) = delete;
  ScopedWindowsHandle& operator=(const ScopedWindowsHandle&) = delete;

  ~ScopedWindowsHandle() {
    if (handle_ != nullptr) {
      ::CloseHandle(handle_);
    }
  }

  bool is_valid() const { return handle_ != nullptr; }

 private:
  HANDLE handle_;
};

void ActivateExistingGhostNetWindow() {
  for (int attempt = 0; attempt < 30; ++attempt) {
    HWND existing_window = ::FindWindowW(nullptr, kGhostNetWindowTitle);

    if (existing_window != nullptr) {
      if (::IsIconic(existing_window)) {
        ::ShowWindow(existing_window, SW_RESTORE);
      } else {
        ::ShowWindow(existing_window, SW_SHOW);
      }

      ::BringWindowToTop(existing_window);
      ::SetForegroundWindow(existing_window);

      FLASHWINFO flash_info = {};
      flash_info.cbSize = sizeof(FLASHWINFO);
      flash_info.hwnd = existing_window;
      flash_info.dwFlags = FLASHW_TRAY | FLASHW_TIMERNOFG;
      flash_info.uCount = 3;
      ::FlashWindowEx(&flash_info);
      return;
    }

    ::Sleep(100);
  }
}

}  // namespace
// GHOSTNET_SINGLE_INSTANCE_HELPERS_END
"""

SINGLE_INSTANCE_GUARD = r"""
  // GHOSTNET_SINGLE_INSTANCE_GUARD_BEGIN
  ScopedWindowsHandle ghostnet_instance_mutex(
      ::CreateMutexW(nullptr, TRUE, kGhostNetSingleInstanceMutex));

  if (!ghostnet_instance_mutex.is_valid()) {
    return EXIT_FAILURE;
  }

  if (::GetLastError() == ERROR_ALREADY_EXISTS) {
    ActivateExistingGhostNetWindow();
    return EXIT_SUCCESS;
  }
  // GHOSTNET_SINGLE_INSTANCE_GUARD_END
"""


def _patch_windows_main_cpp(path: Path):
    if not path.exists():
        return

    text = path.read_text(encoding="utf-8", errors="ignore")

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

    text = text.replace('L"ghostnet_cyber_vpn"', f'L"{APP_NAME}"')
    text = text.replace('L"ghost_net_cyber_vpn"', f'L"{APP_NAME}"')

    if "GHOSTNET_SINGLE_INSTANCE_HELPERS_BEGIN" not in text:
        entry_match = re.search(r'\bint\s+APIENTRY\s+wWinMain\s*\(', text)
        if not entry_match:
            raise RuntimeError("wWinMain was not found in windows/runner/main.cpp")

        text = (
            text[: entry_match.start()]
            + SINGLE_INSTANCE_HELPERS
            + "\n"
            + text[entry_match.start() :]
        )

    if "GHOSTNET_SINGLE_INSTANCE_GUARD_BEGIN" not in text:
        function_match = re.search(
            r'\bint\s+APIENTRY\s+wWinMain\s*\([^)]*\)\s*\{',
            text,
            flags=re.S,
        )
        if not function_match:
            raise RuntimeError(
                "The body of wWinMain was not found in windows/runner/main.cpp"
            )

        insert_at = function_match.end()
        text = text[:insert_at] + "\n" + SINGLE_INSTANCE_GUARD + text[insert_at:]

    path.write_text(text, encoding="utf-8")


def _patch_windows_cmake(path: Path):
    if not path.exists():
        return

    text = path.read_text(encoding="utf-8", errors="ignore")

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

    if "CMAKE_POLICY_VERSION_MINIMUM" not in text:
        text = re.sub(
            r'(cmake_minimum_required\(VERSION[^\n]+\)\s*)',
            r'\1\nset(CMAKE_POLICY_VERSION_MINIMUM 3.5 CACHE STRING "Allow Firebase C++ SDK old CMake policy version" FORCE)\n',
            text,
            count=1,
        )

    path.write_text(text, encoding="utf-8")


_patch_windows_main_cpp(main_cpp)
_patch_windows_cmake(cmake)

print(f"Windows title fixed: {APP_NAME}")
print(f"Windows EXE fixed: {EXE_NAME}.exe")
print("Windows single-instance payment callback fix applied.")
