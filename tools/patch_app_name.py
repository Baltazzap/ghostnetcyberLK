from pathlib import Path
import re

APP_NAME = "GhostNet Cyber VPN"
PACKAGE_NAME = "ru.ghostnet.cybervpn"
PACKAGE_PATH = PACKAGE_NAME.replace(".", "/")

root = Path(__file__).resolve().parents[1]

manifest = root / "android" / "app" / "src" / "main" / "AndroidManifest.xml"
strings = root / "android" / "app" / "src" / "main" / "res" / "values" / "strings.xml"
colors_xml = root / "android" / "app" / "src" / "main" / "res" / "values" / "colors.xml"
notification_icon = root / "android" / "app" / "src" / "main" / "res" / "drawable" / "ic_stat_ghostnet.xml"
update_file_paths = root / "android" / "app" / "src" / "main" / "res" / "xml" / "update_file_paths.xml"
main_activity_template = root / "tools" / "MainActivity.kt.template"

build_gradle = root / "android" / "app" / "build.gradle"
build_gradle_kts = root / "android" / "app" / "build.gradle.kts"
settings_gradle = root / "android" / "settings.gradle"
settings_gradle_kts = root / "android" / "settings.gradle.kts"

kotlin_root = root / "android" / "app" / "src" / "main" / "kotlin"
java_root = root / "android" / "app" / "src" / "main" / "java"

if not manifest.exists():
    raise FileNotFoundError(f"Не найден AndroidManifest.xml: {manifest}")

# 1) Название приложения на Android.
text = manifest.read_text(encoding="utf-8")

if 'android:label=' in text:
    text = re.sub(r'android:label="[^"]*"', 'android:label="@string/app_name"', text)
else:
    text = text.replace("<application", '<application android:label="@string/app_name"', 1)

# Интернет нужен, но незашифрованный HTTP для релиза запрещён.
if 'android.permission.INTERNET' not in text:
    text = re.sub(r'(<manifest[^>]*>)', r'\1\n    <uses-permission android:name="android.permission.INTERNET"/>', text, count=1)

if 'android.permission.POST_NOTIFICATIONS' not in text:
    text = re.sub(r'(<manifest[^>]*>)', r'\1\n    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>', text, count=1)

if 'android.permission.REQUEST_INSTALL_PACKAGES' not in text:
    text = re.sub(
        r'(<manifest[^>]*>)',
        r'\1\n    <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>',
        text,
        count=1,
    )

def _add_app_meta(manifest_text: str, name: str, value_attr: str, value: str) -> str:
    if name in manifest_text:
        return manifest_text
    return manifest_text.replace(
        '</application>',
        f'        <meta-data android:name="{name}" android:{value_attr}="{value}"/>\n    </application>',
        1,
    )

text = _add_app_meta(text, 'com.google.firebase.messaging.default_notification_channel_id', 'value', 'ghostnet_notifications')
text = _add_app_meta(text, 'com.google.firebase.messaging.default_notification_icon', 'resource', '@drawable/ic_stat_ghostnet')
text = _add_app_meta(text, 'com.google.firebase.messaging.default_notification_color', 'resource', '@color/ghostnet_orange')


update_provider = """
        <provider
            android:name="androidx.core.content.FileProvider"
            android:authorities="${applicationId}.update_file_provider"
            android:exported="false"
            android:grantUriPermissions="true">
            <meta-data
                android:name="android.support.FILE_PROVIDER_PATHS"
                android:resource="@xml/update_file_paths" />
        </provider>"""

if '.update_file_provider' not in text:
    text = text.replace('</application>', update_provider + '\n    </application>', 1)

if 'android:usesCleartextTraffic=' in text:
    text = re.sub(r'android:usesCleartextTraffic="[^"]*"', 'android:usesCleartextTraffic="false"', text)
else:
    text = text.replace("<application", '<application android:usesCleartextTraffic="false"', 1)


if 'android:allowBackup=' in text:
    text = re.sub(r'android:allowBackup="[^"]*"', 'android:allowBackup="false"', text)
else:
    text = text.replace("<application", '<application android:allowBackup="false"', 1)

# Deep link для возврата из ЮKassa обратно в приложение: ghostnet://payment-result?payment_id=...
deep_link_filter = """
            <intent-filter android:label=\"GhostNet Payment Return\">
                <action android:name=\"android.intent.action.VIEW\" />
                <category android:name=\"android.intent.category.DEFAULT\" />
                <category android:name=\"android.intent.category.BROWSABLE\" />
                <data android:scheme=\"ghostnet\" android:host=\"payment-result\" />
            </intent-filter>"""

if 'android:scheme=\"ghostnet\"' not in text:
    text = text.replace('</activity>', deep_link_filter + '\n        </activity>', 1)

manifest.write_text(text, encoding="utf-8")

strings.parent.mkdir(parents=True, exist_ok=True)
strings.write_text(
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<resources>\n'
    f'    <string name="app_name">{APP_NAME}</string>\n'
    '</resources>\n',
    encoding="utf-8",
)

colors_xml.parent.mkdir(parents=True, exist_ok=True)
colors_xml.write_text(
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<resources>\n'
    '    <color name="ghostnet_orange">#FF7A00</color>\n'
    '</resources>\n',
    encoding="utf-8",
)

notification_icon.parent.mkdir(parents=True, exist_ok=True)
notification_icon.write_text(
    '''<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24">
    <path
        android:fillColor="#FFFFFFFF"
        android:pathData="M12,2C8.7,2 6,4.7 6,8v3.6L4.3,15.3C4,16 4.5,17 5.3,17h13.4c0.8,0 1.3,-1 1,-1.7L18,11.6V8c0,-3.3 -2.7,-6 -6,-6zM10,20c0.4,1.2 1.5,2 2,2s1.6,-0.8 2,-2h-4z"/>
</vector>
''',
    encoding="utf-8",
)


update_file_paths.parent.mkdir(parents=True, exist_ok=True)
update_file_paths.write_text(
    """<?xml version="1.0" encoding="utf-8"?>
<paths xmlns:android="http://schemas.android.com/apk/res/android">
    <cache-path name="ghostnet_updates" path="updates/" />
</paths>
""",
    encoding="utf-8",
)

# 2) applicationId / namespace.
if build_gradle.exists():
    g = build_gradle.read_text(encoding="utf-8")
    g = re.sub(r'namespace\s*(?:=)?\s*["\'][^"\']+["\']', f'namespace "{PACKAGE_NAME}"', g)
    g = re.sub(r'applicationId\s*(?:=)?\s*["\'][^"\']+["\']', f'applicationId "{PACKAGE_NAME}"', g)
    build_gradle.write_text(g, encoding="utf-8")

if build_gradle_kts.exists():
    g = build_gradle_kts.read_text(encoding="utf-8")
    g = re.sub(r'namespace\s*=\s*["\'][^"\']+["\']', f'namespace = "{PACKAGE_NAME}"', g)
    g = re.sub(r'applicationId\s*=\s*["\'][^"\']+["\']', f'applicationId = "{PACKAGE_NAME}"', g)
    g = re.sub(r'namespace\s+["\'][^"\']+["\']', f'namespace = "{PACKAGE_NAME}"', g)
    g = re.sub(r'applicationId\s+["\'][^"\']+["\']', f'applicationId = "{PACKAGE_NAME}"', g)
    build_gradle_kts.write_text(g, encoding="utf-8")


# 2.5) Firebase Google Services plugin for Android push notifications.
def _patch_settings_gradle(path: Path):
    if not path.exists():
        return
    g = path.read_text(encoding="utf-8")
    if "com.google.gms.google-services" in g:
        path.write_text(g, encoding="utf-8")
        return
    if "plugins {" in g:
        if path.suffix == ".kts" or 'id("dev.flutter.flutter-plugin-loader")' in g:
            line = '    id("com.google.gms.google-services") version "4.4.2" apply false\n'
        else:
            line = '    id "com.google.gms.google-services" version "4.4.2" apply false\n'
        g = g.replace("plugins {", "plugins {\n" + line, 1)
    path.write_text(g, encoding="utf-8")


def _insert_line_into_named_block(text: str, block_name: str, line: str) -> str:
    """Insert a line near the top of a simple Gradle block: blockName { ... }."""
    idx = text.find(block_name + " {")
    if idx == -1:
        return text
    open_idx = text.find("{", idx)
    if open_idx == -1:
        return text
    insert_at = open_idx + 1
    return text[:insert_at] + "\n" + line + text[insert_at:]


def _append_block_if_missing(text: str, block_name: str, block_body: str) -> str:
    if block_name + " {" in text:
        return text
    return text.rstrip() + f"\n\n{block_name} {{\n{block_body}\n}}\n"


def _patch_desugaring(path: Path, text: str) -> str:
    """Enable Android core library desugaring required by flutter_local_notifications."""
    is_kts = path.suffix == ".kts" or 'id("com.android.application")' in text

    if is_kts:
        desugar_flag = "        isCoreLibraryDesugaringEnabled = true"
        dependency_line = '    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")'
        compile_options_block = (
            "    compileOptions {\n"
            "        sourceCompatibility = JavaVersion.VERSION_17\n"
            "        targetCompatibility = JavaVersion.VERSION_17\n"
            "        isCoreLibraryDesugaringEnabled = true\n"
            "    }"
        )
    else:
        desugar_flag = "        coreLibraryDesugaringEnabled true"
        dependency_line = "    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.5'"
        compile_options_block = (
            "    compileOptions {\n"
            "        sourceCompatibility JavaVersion.VERSION_17\n"
            "        targetCompatibility JavaVersion.VERSION_17\n"
            "        coreLibraryDesugaringEnabled true\n"
            "    }"
        )

    if "coreLibraryDesugaringEnabled" not in text and "isCoreLibraryDesugaringEnabled" not in text:
        if "compileOptions {" in text:
            text = text.replace("compileOptions {", "compileOptions {\n" + desugar_flag, 1)
        elif "android {" in text:
            text = _insert_line_into_named_block(text, "android", compile_options_block)
        else:
            text += "\n\nandroid {\n" + compile_options_block + "\n}\n"

    if "desugar_jdk_libs" not in text:
        if "dependencies {" in text:
            text = text.replace("dependencies {", "dependencies {\n" + dependency_line, 1)
        else:
            text += "\n\ndependencies {\n" + dependency_line + "\n}\n"

    return text


def _patch_app_gradle(path: Path):
    if not path.exists():
        return
    g = path.read_text(encoding="utf-8")


    if path.suffix == ".kts":
        g = re.sub(
            r'minSdk\s*=\s*(?:flutter\.minSdkVersion|\d+)',
            'minSdk = 23',
            g,
        )
    else:
        g = re.sub(
            r'minSdkVersion\s+(?:flutter\.minSdkVersion|\d+)',
            'minSdkVersion 23',
            g,
        )

    if "com.google.gms.google-services" not in g:
        if "plugins {" in g:
            if path.suffix == ".kts" or 'id("com.android.application")' in g:
                line = '    id("com.google.gms.google-services")\n'
            else:
                line = '    id "com.google.gms.google-services"\n'
            g = g.replace("plugins {", "plugins {\n" + line, 1)
        else:
            g += "\napply plugin: 'com.google.gms.google-services'\n"

    g = _patch_desugaring(path, g)
    path.write_text(g, encoding="utf-8")


_patch_settings_gradle(settings_gradle)
_patch_settings_gradle(settings_gradle_kts)
_patch_app_gradle(build_gradle)
_patch_app_gradle(build_gradle_kts)

# 3) Удаляем дубликаты MainActivity и создаём один правильный файл.
target_dir = kotlin_root / PACKAGE_PATH
target_dir.mkdir(parents=True, exist_ok=True)
target_file = target_dir / "MainActivity.kt"

if not main_activity_template.exists():
    raise FileNotFoundError(
        f"Не найден шаблон MainActivity: {main_activity_template}"
    )

main_activity_code = main_activity_template.read_text(
    encoding="utf-8"
).replace("__PACKAGE_NAME__", PACKAGE_NAME)

for src_root in [kotlin_root, java_root]:
    if not src_root.exists():
        continue

    for file in list(src_root.rglob("MainActivity.kt")) + list(src_root.rglob("MainActivity.java")):
        try:
            if file.resolve() != target_file.resolve():
                file.unlink()
        except FileNotFoundError:
            pass

target_file.write_text(main_activity_code, encoding="utf-8")

# Удаляем пустые папки старых пакетов.
for src_root in [kotlin_root, java_root]:
    if not src_root.exists():
        continue
    folders = [p for p in src_root.rglob("*") if p.is_dir()]
    folders.sort(key=lambda p: len(str(p)), reverse=True)
    for folder in folders:
        try:
            if folder != target_dir and not any(folder.iterdir()):
                folder.rmdir()
        except OSError:
            pass

print(f"Android label fixed: {APP_NAME}")
print(f"Android package fixed: {PACKAGE_NAME}")
print("MainActivity duplicates removed.")
