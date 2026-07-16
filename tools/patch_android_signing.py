from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
kts = root / "android" / "app" / "build.gradle.kts"
groovy = root / "android" / "app" / "build.gradle"

KTS_SIGNING_BLOCK = r'''
    signingConfigs {
        create("release") {
            val storePath = System.getenv("ANDROID_KEYSTORE_PATH")
                ?: throw GradleException("ANDROID_KEYSTORE_PATH is not configured.")
            val storePasswordValue = System.getenv("ANDROID_KEYSTORE_PASSWORD")
                ?: throw GradleException("ANDROID_KEYSTORE_PASSWORD is not configured.")
            val keyAliasValue = System.getenv("ANDROID_KEY_ALIAS")
                ?: throw GradleException("ANDROID_KEY_ALIAS is not configured.")
            val keyPasswordValue = System.getenv("ANDROID_KEY_PASSWORD")
                ?: throw GradleException("ANDROID_KEY_PASSWORD is not configured.")

            storeFile = file(storePath)
            storePassword = storePasswordValue
            keyAlias = keyAliasValue
            keyPassword = keyPasswordValue

            enableV1Signing = true
            enableV2Signing = true
            enableV3Signing = true
            enableV4Signing = true
        }
    }

'''

GROOVY_SIGNING_BLOCK = r'''
    signingConfigs {
        release {
            def storePath = System.getenv("ANDROID_KEYSTORE_PATH")
            def storePasswordValue = System.getenv("ANDROID_KEYSTORE_PASSWORD")
            def keyAliasValue = System.getenv("ANDROID_KEY_ALIAS")
            def keyPasswordValue = System.getenv("ANDROID_KEY_PASSWORD")

            if (!storePath || !storePasswordValue || !keyAliasValue || !keyPasswordValue) {
                throw new GradleException("Android release signing environment is incomplete.")
            }

            storeFile file(storePath)
            storePassword storePasswordValue
            keyAlias keyAliasValue
            keyPassword keyPasswordValue

            v1SigningEnabled true
            v2SigningEnabled true
            enableV3Signing true
            enableV4Signing true
        }
    }

'''

def patch_kts(path: Path) -> None:
    text = path.read_text(encoding="utf-8")
    if 'create("release")' not in text:
        marker = "    buildTypes {"
        if marker not in text:
            raise RuntimeError("buildTypes block was not found in build.gradle.kts")
        text = text.replace(marker, KTS_SIGNING_BLOCK + marker, 1)

    if 'signingConfig = signingConfigs.getByName("debug")' in text:
        text = text.replace(
            'signingConfig = signingConfigs.getByName("debug")',
            'signingConfig = signingConfigs.getByName("release")',
        )
    elif 'signingConfig = signingConfigs.getByName("release")' not in text:
        text, count = re.subn(
            r'(getByName\("release"\)\s*\{)',
            r'\1\n            signingConfig = signingConfigs.getByName("release")',
            text,
            count=1,
        )
        if count == 0:
            raise RuntimeError("Release build type was not found in build.gradle.kts")
    path.write_text(text, encoding="utf-8")

def patch_groovy(path: Path) -> None:
    text = path.read_text(encoding="utf-8")
    if "ANDROID_KEYSTORE_PATH" not in text:
        marker = "    buildTypes {"
        if marker not in text:
            raise RuntimeError("buildTypes block was not found in build.gradle")
        text = text.replace(marker, GROOVY_SIGNING_BLOCK + marker, 1)

    text = re.sub(
        r"signingConfig\s+signingConfigs\.debug",
        "signingConfig signingConfigs.release",
        text,
    )
    if "signingConfig signingConfigs.release" not in text:
        text, count = re.subn(
            r"(release\s*\{)",
            r"\1\n            signingConfig signingConfigs.release",
            text,
            count=1,
        )
        if count == 0:
            raise RuntimeError("Release build type was not found in build.gradle")
    path.write_text(text, encoding="utf-8")

if kts.exists():
    patch_kts(kts)
    print(f"Android signing patched: {kts}")
elif groovy.exists():
    patch_groovy(groovy)
    print(f"Android signing patched: {groovy}")
else:
    raise FileNotFoundError("Neither build.gradle.kts nor build.gradle was found.")
