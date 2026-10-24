# Full check for the assignment: docker compose up, ps, CRUD requests,
# data persistence after docker compose down / up, docker compose logs.
# Every step is printed to the console and saved to docs\*.txt.
#
# Run from the project root (Windows PowerShell 5.1 or PowerShell 7):
#   powershell -ExecutionPolicy Bypass -File .\scripts\verify.ps1

$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$docs = Join-Path $root 'docs'
New-Item -ItemType Directory -Force -Path $docs | Out-Null

$baseUrl = 'http://localhost:8080'
$psFile = Join-Path $docs '01-compose-ps.txt'
$crudFile = Join-Path $docs '02-crud.txt'
$persistenceFile = Join-Path $docs '03-persistence.txt'
$logsFile = Join-Path $docs '04-compose-logs.txt'
$psqlArgs = @('compose', 'exec', '-T', 'db', 'psql', '-U', 'postgres', '-d', 'app', '-c',
    'SELECT id, title, is_completed, created_at, updated_at FROM tasks ORDER BY id;')
$script:LastOutput = @()

function Initialize-File([string]$File, [string]$Title) {
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
    Write-Host 'API did not become ready. Check: docker compose logs api' -ForegroundColor Red
    exit 1
}

# 1. Start the stack and show running services
Initialize-File $psFile 'docker compose up + docker compose ps'
Invoke-Step $psFile 'docker' @('compose', 'up', '-d', '--build')
Wait-Api
Invoke-Step $psFile 'docker' @('compose', 'ps')

# 2. CRUD: create two tasks, read, update the first, delete the second
Initialize-File $crudFile 'CRUD requests to the API'
Invoke-Api $crudFile 'GET' '/tasks'
Invoke-Api $crudFile 'POST' '/tasks' 'requests/create-task.json'
$firstId = Get-CreatedId
Invoke-Api $crudFile 'POST' '/tasks' 'requests/create-task-2.json'
$secondId = Get-CreatedId
Invoke-Api $crudFile 'GET' '/tasks'
Invoke-Api $crudFile 'GET' "/tasks/$firstId"
Invoke-Api $crudFile 'PUT' "/tasks/$firstId" 'requests/update-task.json'
Invoke-Api $crudFile 'DELETE' "/tasks/$secondId"
Invoke-Api $crudFile 'GET' "/tasks/$secondId"
Invoke-Api $crudFile 'GET' '/tasks'
Invoke-Step $crudFile 'docker' $psqlArgs

# 3. Logs of the first run (containers are removed by "down", so save them now)
Initialize-File $logsFile 'docker compose logs'
Invoke-Step $logsFile 'docker' @('compose', 'logs', '--no-color')

# 4. Restart the stack and check that the data is still in PostgreSQL
Initialize-File $persistenceFile 'Data persistence after docker compose down / up'
Invoke-Step $persistenceFile 'docker' @('compose', 'down')
Invoke-Step $persistenceFile 'docker' @('volume', 'ls', '--filter', 'name=db_data')
Invoke-Step $persistenceFile 'docker' @('compose', 'up', '-d')
Wait-Api
Invoke-Step $persistenceFile 'docker' @('compose', 'ps')
Invoke-Api $persistenceFile 'GET' '/tasks'
Invoke-Api $persistenceFile 'GET' "/tasks/$firstId"
Invoke-Step $persistenceFile 'docker' $psqlArgs

# 5. Logs after the restart
Write-Log $logsFile @('', '# ---------- after docker compose down / up ----------')
Invoke-Step $logsFile 'docker' @('compose', 'logs', '--no-color')

Write-Host ''
Write-Host "Done. Results are saved to $docs" -ForegroundColor Green
