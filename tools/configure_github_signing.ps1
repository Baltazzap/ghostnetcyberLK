param(
  [string]$Repo = "",
  [string]$AndroidKeystorePath = "",
  [string]$AndroidPassword = "",
  [string]$AndroidAlias = "ghostnet_release",
  [string]$WindowsPfxPath = "",
  [string]$WindowsPfxPassword = ""
)

$ErrorActionPreference = "Stop"

$gh = Get-Command gh.exe -ErrorAction SilentlyContinue
if (-not $gh) {
  $gh = Get-Command gh -ErrorAction SilentlyContinue
}

if (-not $gh) {
  throw @"
GitHub CLI is not installed.
Install it with:
winget install --id GitHub.cli
Then run:
gh auth login
"@
}

& $gh.Source auth status
if ($LASTEXITCODE -ne 0) {
  throw "GitHub CLI is not authenticated. Run: gh auth login"
}

$repoArgs = @()
if (-not [string]::IsNullOrWhiteSpace($Repo)) {
  $repoArgs = @("--repo", $Repo)
}

function Set-GitHubSecret {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Name,

    [Parameter(Mandatory = $true)]
    [string]$Value
  )

  if ([string]::IsNullOrWhiteSpace($Value)) {
    throw "Secret value is empty: $Name"
  }

  $arguments = @(
    "secret",
    "set",
    $Name
  ) + $repoArgs + @(
    "--body",
    "-"
  )

  $startInfo = New-Object System.Diagnostics.ProcessStartInfo
  $startInfo.FileName = $gh.Source
  $startInfo.UseShellExecute = $false
  $startInfo.RedirectStandardInput = $true
  $startInfo.RedirectStandardOutput = $true
  $startInfo.RedirectStandardError = $true

  foreach ($argument in $arguments) {
    [void]$startInfo.ArgumentList.Add($argument)
  }

  $process = New-Object System.Diagnostics.Process
  $process.StartInfo = $startInfo

  [void]$process.Start()

  # Write() is used intentionally instead of WriteLine() so GitHub stores
  # the exact secret without a trailing CRLF from Windows PowerShell.
  $process.StandardInput.Write($Value)
  $process.StandardInput.Close()

  $stdout = $process.StandardOutput.ReadToEnd()
  $stderr = $process.StandardError.ReadToEnd()

  $process.WaitForExit()

  if ($process.ExitCode -ne 0) {
    throw "Failed to set GitHub Secret $Name. $stderr"
  }

  if (-not [string]::IsNullOrWhiteSpace($stdout)) {
    Write-Host $stdout.Trim()
  }

  Write-Host "Configured: $Name"
}

if (-not [string]::IsNullOrWhiteSpace($AndroidKeystorePath)) {
  if (-not (Test-Path $AndroidKeystorePath)) {
    throw "Android keystore was not found: $AndroidKeystorePath"
  }

  if ([string]::IsNullOrWhiteSpace($AndroidPassword)) {
    throw "AndroidPassword is required."
  }

  $keystoreBytes = [System.IO.File]::ReadAllBytes(
    (Resolve-Path $AndroidKeystorePath)
  )
  $keystoreBase64 = [Convert]::ToBase64String($keystoreBytes)

  Set-GitHubSecret `
    -Name "ANDROID_KEYSTORE_BASE64" `
    -Value $keystoreBase64

  Set-GitHubSecret `
    -Name "ANDROID_KEYSTORE_PASSWORD" `
    -Value $AndroidPassword

  Set-GitHubSecret `
    -Name "ANDROID_KEY_ALIAS" `
    -Value $AndroidAlias

  Set-GitHubSecret `
    -Name "ANDROID_KEY_PASSWORD" `
    -Value $AndroidPassword
}

if (-not [string]::IsNullOrWhiteSpace($WindowsPfxPath)) {
  if (-not (Test-Path $WindowsPfxPath)) {
    throw "Windows PFX was not found: $WindowsPfxPath"
  }

  if ([string]::IsNullOrWhiteSpace($WindowsPfxPassword)) {
    throw "WindowsPfxPassword is required."
  }

  $pfxBytes = [System.IO.File]::ReadAllBytes(
    (Resolve-Path $WindowsPfxPath)
  )
  $pfxBase64 = [Convert]::ToBase64String($pfxBytes)

  Set-GitHubSecret `
    -Name "WINDOWS_CERTIFICATE_BASE64" `
    -Value $pfxBase64

  Set-GitHubSecret `
    -Name "WINDOWS_CERTIFICATE_PASSWORD" `
    -Value $WindowsPfxPassword
}

Write-Host ""
Write-Host "GitHub signing secrets are configured."
