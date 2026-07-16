param(
  [Parameter(Mandatory = $true)]
  [string]$Path,
  [string]$Output = ""
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $Path)) {
  throw "File was not found: $Path"
}

if ([string]::IsNullOrWhiteSpace($Output)) {
  $Output = "$Path.base64.txt"
}

$bytes = [System.IO.File]::ReadAllBytes((Resolve-Path $Path))
[System.IO.File]::WriteAllText($Output, [Convert]::ToBase64String($bytes))

Write-Host "Base64 secret created:"
Write-Host $Output
