$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$kokoro = Join-Path $root "kokoro"
$sillyTavern = Join-Path $root "SillyTavern"
$kokoroUrl = "http://127.0.0.1:5173/kokoro/avatar.html"

if (-not (Test-Path $kokoro)) {
    throw "kokoro directory was not found: $kokoro"
}

if (-not (Test-Path $sillyTavern)) {
    throw "SillyTavern directory was not found: $sillyTavern"
}

function Wait-HttpOk {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url,
        [int]$TimeoutSeconds = 45
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        try {
            $response = Invoke-WebRequest -UseBasicParsing -Uri $Url -TimeoutSec 2
            if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 400) {
                return
            }
        } catch {
            Start-Sleep -Milliseconds 500
        }
    } while ((Get-Date) -lt $deadline)

    throw "Timed out waiting for $Url"
}

Start-Process powershell -ArgumentList @(
    "-NoExit",
    "-Command",
    "Set-Location -LiteralPath '$kokoro'; npm.cmd run dev -- --host 127.0.0.1 --port 5173"
)

Write-Host "Waiting for Kokoro avatar server: $kokoroUrl"
Wait-HttpOk -Url $kokoroUrl
Write-Host "Kokoro avatar server is ready."

Start-Process powershell -ArgumentList @(
    "-NoExit",
    "-Command",
    "Set-Location -LiteralPath '$sillyTavern'; npm.cmd run start"
)

Write-Host "Started kokoro and SillyTavern in separate PowerShell windows."
