$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$signingDir = Join-Path $root "signing"
$keystore = Join-Path $signingDir "ghostnet-release.jks"
$base64File = Join-Path $signingDir "ANDROID_KEYSTORE_BASE64.txt"
$alias = "ghostnet_release"

New-Item -ItemType Directory -Path $signingDir -Force | Out-Null

if (Test-Path $keystore) {
  throw "Keystore already exists: $keystore"
}

$keytool = Get-Command keytool.exe -ErrorAction SilentlyContinue
if (-not $keytool) {
  throw "keytool.exe was not found. Install JDK 17 first."
}

$passwordSecure = Read-Host "Enter a strong password for the Android signing key" -AsSecureString
$passwordConfirmSecure = Read-Host "Repeat the password" -AsSecureString

$password = [System.Net.NetworkCredential]::new("", $passwordSecure).Password
$passwordConfirm = [System.Net.NetworkCredential]::new("", $passwordConfirmSecure).Password

if ([string]::IsNullOrWhiteSpace($password)) {
  throw "Password cannot be empty."
}
if ($password -ne $passwordConfirm) {
  throw "Passwords do not match."
}

& $keytool.Source `
  -genkeypair `
  -v `
  -keystore $keystore `
  -storetype JKS `
  -storepass $password `
  -keypass $password `
  -alias $alias `
  -keyalg RSA `
  -keysize 4096 `
  -sigalg SHA256withRSA `
  -validity 10000 `
  -dname "CN=GhostNet Cyber VPN, OU=GhostNet, O=GhostNet Cyber VPN, C=NL"

if ($LASTEXITCODE -ne 0) {
  throw "keytool failed with code $LASTEXITCODE"
}

$bytes = [System.IO.File]::ReadAllBytes($keystore)
[System.IO.File]::WriteAllText($base64File, [Convert]::ToBase64String($bytes))

Write-Host ""
Write-Host "Android signing key created:"
Write-Host $keystore
Write-Host ""
Write-Host "GitHub Secrets:"
Write-Host "ANDROID_KEYSTORE_BASE64 = contents of:"
Write-Host $base64File
Write-Host "ANDROID_KEYSTORE_PASSWORD = the password you entered"
Write-Host "ANDROID_KEY_ALIAS = $alias"
Write-Host "ANDROID_KEY_PASSWORD = the same password"
Write-Host ""
Write-Host "Back up the JKS and password in two secure places."
