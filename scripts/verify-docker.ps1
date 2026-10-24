# Check for the "API in a Docker container" assignment: docker build, docker run -p,
# docker ps, requests to the API from outside the container, docker logs.
# Every step is printed to the console and saved to docs\docker\*.txt.
#
# Run from the project root (Windows PowerShell 5.1 or PowerShell 7):
#   powershell -ExecutionPolicy Bypass -File .\scripts\verify-docker.ps1

. (Join-Path $PSScriptRoot 'common.ps1')

$image = 'task-api'
$container = 'task-api'
$buildFile = 'docs\docker\01-docker-build.txt'
$runFile = 'docs\docker\02-docker-run-ps.txt'
$apiFile = 'docs\docker\03-api-requests.txt'
$logsFile = 'docs\docker\04-docker-logs.txt'

# Free port 8080: stop the compose stack (its data in db_data is kept) and a container left from a previous run
Write-Host 'Freeing port 8080 (docker compose down, docker rm -f task-api) ...'
& docker compose down 2>&1 | Out-Null
& docker rm -f $container 2>&1 | Out-Null

# 1. Build the image from task-api/Dockerfile
Initialize-File $buildFile 'docker build'
Invoke-Step $buildFile 'docker' @('build', '-t', $image, './task-api')

# 2. Run the container with port 8080 published. Profile standalone = in-memory H2, PostgreSQL is not needed
Initialize-File $runFile 'docker run -p + docker ps'
Invoke-Step $runFile 'docker' @('run', '-d', '--name', $container, '-p', '8080:8080', '-e', 'SPRING_PROFILES_ACTIVE=standalone', $image)
Wait-Api
Invoke-Step $runFile 'docker' @('ps')

# 3. Requests to the API from outside the container
Initialize-File $apiFile 'Requests to the API in the container'
Invoke-Api $apiFile 'GET' '/health'
Invoke-Api $apiFile 'GET' '/tasks'
Invoke-Api $apiFile 'POST' '/tasks' 'requests/create-task.json'
$taskId = Get-CreatedId
Invoke-Api $apiFile 'GET' "/tasks/$taskId"
Invoke-Api $apiFile 'GET' '/tasks'

# 4. Container logs
Initialize-File $logsFile 'docker logs'
Invoke-Step $logsFile 'docker' @('logs', $container)

Write-Host ''
Write-Host "Done. Results are saved to $(Resolve-Path 'docs\docker')" -ForegroundColor Green
Write-Host "Container '$container' is still running: open $baseUrl/tasks in a browser. Stop it with: docker rm -f $container"
