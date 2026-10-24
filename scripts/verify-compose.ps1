# Check for the "Docker Compose + PostgreSQL" assignment: docker compose up, ps, CRUD requests,
# data persistence after docker compose down / up, docker compose logs.
# Every step is printed to the console and saved to docs\compose\*.txt.
#
# Run from the project root (Windows PowerShell 5.1 or PowerShell 7):
#   powershell -ExecutionPolicy Bypass -File .\scripts\verify-compose.ps1

. (Join-Path $PSScriptRoot 'common.ps1')

$psFile = 'docs\compose\01-compose-ps.txt'
$crudFile = 'docs\compose\02-crud.txt'
$persistenceFile = 'docs\compose\03-persistence.txt'
$logsFile = 'docs\compose\04-compose-logs.txt'
$psqlArgs = @('compose', 'exec', '-T', 'db', 'psql', '-U', 'postgres', '-d', 'app', '-c',
    'SELECT id, title, completed, created_at, updated_at FROM tasks ORDER BY id;')

# Free port 8080 if the single container from verify-docker is still running
& docker rm -f task-api 2>&1 | Out-Null

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
Write-Host "Done. Results are saved to $(Resolve-Path 'docs\compose')" -ForegroundColor Green
