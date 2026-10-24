#!/usr/bin/env bash
# Check for the "API in a Docker container" assignment: docker build, docker run -p,
# docker ps, requests to the API from outside the container, docker logs.
# Every step is printed to the console and saved to docs/docker/*.txt.
#
# Run (Linux / macOS / Git Bash):  bash scripts/verify-docker.sh
set -uo pipefail
source "$(dirname "$0")/common.sh"

IMAGE=task-api
CONTAINER=task-api
BUILD_FILE=docs/docker/01-docker-build.txt
RUN_FILE=docs/docker/02-docker-run-ps.txt
API_FILE=docs/docker/03-api-requests.txt
LOGS_FILE=docs/docker/04-docker-logs.txt

# Free port 8080: stop the compose stack (its data in db_data is kept) and a container left from a previous run
echo "Freeing port 8080 (docker compose down, docker rm -f $CONTAINER) ..."
docker compose down > /dev/null 2>&1
docker rm -f "$CONTAINER" > /dev/null 2>&1

# 1. Build the image from task-api/Dockerfile
init_file "$BUILD_FILE" "docker build"
step "$BUILD_FILE" docker build -t "$IMAGE" ./task-api

# 2. Run the container with port 8080 published. Profile standalone = in-memory H2, PostgreSQL is not needed
init_file "$RUN_FILE" "docker run -p + docker ps"
step "$RUN_FILE" docker run -d --name "$CONTAINER" -p 8080:8080 -e SPRING_PROFILES_ACTIVE=standalone "$IMAGE"
wait_api
step "$RUN_FILE" docker ps

# 3. Requests to the API from outside the container
init_file "$API_FILE" "Requests to the API in the container"
api "$API_FILE" GET /health
api "$API_FILE" GET /tasks
api "$API_FILE" POST /tasks requests/create-task.json
TASK_ID=$(created_id) || exit 1
api "$API_FILE" GET "/tasks/$TASK_ID"
api "$API_FILE" GET /tasks

# 4. Container logs
init_file "$LOGS_FILE" "docker logs"
step "$LOGS_FILE" docker logs "$CONTAINER"

echo
echo "Done. Results are saved to $(pwd)/docs/docker"
echo "Container '$CONTAINER' is still running: open $BASE_URL/tasks in a browser. Stop it with: docker rm -f $CONTAINER"
