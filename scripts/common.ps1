# Shared helpers for verify-docker.ps1 and verify-compose.ps1.
# Those scripts dot-source this file; it is not meant to be run on its own.

$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

Set-Location (Split-Path -Parent $PSScriptRoot)
$baseUrl = 'http://localhost:8080'
$script:LastOutput = @()

function Initialize-File([string]$File, [string]$Title) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $File) | Out-Null
    $header = "# $Title ($(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))"
    Write-Host $header -ForegroundColor Cyan
    Set-Content -Path $File -Value $header -Encoding UTF8
}

function Write-Log([string]$File, $Lines) {
    if ($null -eq $Lines) { return }
    $Lines | ForEach-Object { Write-Host $_ }
    Add-Content -Path $File -Value $Lines -Encoding UTF8
}

# Runs a native command and writes "> command" plus its stdout and stderr to the console and the file.
function Invoke-Step([string]$File, [string]$Exe, [string[]]$Arguments) {
    $shown = ($Arguments | ForEach-Object { if ($_ -match '\s') { "`"$_`"" } else { $_ } }) -join ' '
    Write-Log $File @('', "> $Exe $shown")
    $script:LastOutput = @(& $Exe @Arguments 2>&1 | ForEach-Object {
        if ($_ -is [System.Management.Automation.ErrorRecord]) { $_.Exception.Message } else { "$_" }
    })
    Write-Log $File $script:LastOutput
}

function Invoke-Api([string]$File, [string]$Method, [string]$Path, [string]$BodyFile) {
    $arguments = @('-s', '-i', '-X', $Method)
    if ($BodyFile) { $arguments += @('-H', 'Content-Type: application/json', '-d', "@$BodyFile") }
    Invoke-Step $File 'curl.exe' ($arguments + "$baseUrl$Path")
}

function Get-CreatedId {
    $id = $null
    try { $id = ($script:LastOutput[-1] | ConvertFrom-Json).id } catch { }
    if (-not $id) {
        Write-Host 'POST /tasks did not return a created task, stopping.' -ForegroundColor Red
        exit 1
    }
    return $id
}

function Wait-Api {
    Write-Host "Waiting for API at $baseUrl/health ..."
    for ($i = 0; $i -lt 60; $i++) {
        try {
            $response = Invoke-WebRequest -Uri "$baseUrl/health" -UseBasicParsing -TimeoutSec 3
            if ($response.StatusCode -eq 200) { Write-Host 'API is ready'; return }
        } catch { }
        Start-Sleep -Seconds 2
    }
    Write-Host 'API did not become ready. Check the logs: docker logs task-api / docker compose logs api' -ForegroundColor Red
    exit 1
}
