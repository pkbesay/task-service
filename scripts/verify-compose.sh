#!/usr/bin/env bash
# Check for the "Docker Compose + PostgreSQL" assignment: docker compose up, ps, CRUD requests,
# data persistence after docker compose down / up, docker compose logs.
# Every step is printed to the console and saved to docs/compose/*.txt.
#
# Run (Linux / macOS / Git Bash):  bash scripts/verify-compose.sh
set -uo pipefail
source "$(dirname "$0")/common.sh"

PS_FILE=docs/compose/01-compose-ps.txt
CRUD_FILE=docs/compose/02-crud.txt
PERSISTENCE_FILE=docs/compose/03-persistence.txt
LOGS_FILE=docs/compose/04-compose-logs.txt
PSQL=(docker compose exec -T db psql -U postgres -d app -c
  "SELECT id, title, completed, created_at, updated_at FROM tasks ORDER BY id;")

# Free port 8080 if the single container from verify-docker is still running
docker rm -f task-api > /dev/null 2>&1

# 1. Start the stack and show running services
init_file "$PS_FILE" "docker compose up + docker compose ps"
step "$PS_FILE" docker compose up -d --build
wait_api
step "$PS_FILE" docker compose ps

# 2. CRUD: create two tasks, read, update the first, delete the second
init_file "$CRUD_FILE" "CRUD requests to the API"
api "$CRUD_FILE" GET /tasks
api "$CRUD_FILE" POST /tasks requests/create-task.json
FIRST_ID=$(created_id) || exit 1
api "$CRUD_FILE" POST /tasks requests/create-task-2.json
SECOND_ID=$(created_id) || exit 1
api "$CRUD_FILE" GET /tasks
api "$CRUD_FILE" GET "/tasks/$FIRST_ID"
api "$CRUD_FILE" PUT "/tasks/$FIRST_ID" requests/update-task.json
api "$CRUD_FILE" DELETE "/tasks/$SECOND_ID"
api "$CRUD_FILE" GET "/tasks/$SECOND_ID"
api "$CRUD_FILE" GET /tasks
step "$CRUD_FILE" "${PSQL[@]}"

# 3. Logs of the first run (containers are removed by "down", so save them now)
init_file "$LOGS_FILE" "docker compose logs"
step "$LOGS_FILE" docker compose logs --no-color

# 4. Restart the stack and check that the data is still in PostgreSQL
init_file "$PERSISTENCE_FILE" "Data persistence after docker compose down / up"
step "$PERSISTENCE_FILE" docker compose down
step "$PERSISTENCE_FILE" docker volume ls --filter name=db_data
step "$PERSISTENCE_FILE" docker compose up -d
wait_api
step "$PERSISTENCE_FILE" docker compose ps
api "$PERSISTENCE_FILE" GET /tasks
api "$PERSISTENCE_FILE" GET "/tasks/$FIRST_ID"
step "$PERSISTENCE_FILE" "${PSQL[@]}"

# 5. Logs after the restart
printf '\n# ---------- after docker compose down / up ----------\n' | tee -a "$LOGS_FILE"
step "$LOGS_FILE" docker compose logs --no-color

echo
echo "Done. Results are saved to $(pwd)/docs/compose"
