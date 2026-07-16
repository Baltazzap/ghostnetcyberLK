param(
  [Parameter(Mandatory = $true)]
  [string]$FilePath,

  [Parameter(Mandatory = $true)]
  [string]$CertificatePath,

  [Parameter(Mandatory = $true)]
  [string]$CertificatePassword,

  [string]$Description = "GhostNet Cyber VPN",
  [string]$DescriptionUrl = "https://ghostnetcyber.ru",
  [string]$TimestampUrl = "http://timestamp.digicert.com"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $FilePath)) {
  throw "File to sign was not found: $FilePath"
}
if (-not (Test-Path $CertificatePath)) {
  throw "Code-signing certificate was not found: $CertificatePath"
}

$signtool = Get-ChildItem `
  -Path "${env:ProgramFiles(x86)}\Windows Kits\10\bin\*\x64\signtool.exe" `
  -ErrorAction SilentlyContinue |
  Sort-Object FullName -Descending |
  Select-Object -First 1

if (-not $signtool) {
  throw "signtool.exe was not found in Windows SDK."
}

Write-Host "SignTool: $($signtool.FullName)"
Write-Host "Signing: $FilePath"

& $signtool.FullName sign `
  /f $CertificatePath `
  /p $CertificatePassword `
  /fd SHA256 `
  /tr $TimestampUrl `
  /td SHA256 `
  /d $Description `
  /du $DescriptionUrl `
  $FilePath

if ($LASTEXITCODE -ne 0) {
  throw "SignTool sign failed with code $LASTEXITCODE"
}

& $signtool.FullName verify /pa /all /v $FilePath
if ($LASTEXITCODE -ne 0) {
  throw "SignTool verify failed with code $LASTEXITCODE"
}

Write-Host "Signature verified: $FilePath"
