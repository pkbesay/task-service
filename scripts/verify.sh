#!/usr/bin/env bash
# Full check for the assignment: docker compose up, ps, CRUD requests,
# data persistence after docker compose down / up, docker compose logs.
# Every step is printed to the console and saved to docs/*.txt.
#
# Run (Linux / macOS / Git Bash):  bash scripts/verify.sh
set -uo pipefail

cd "$(dirname "$0")/.."
mkdir -p docs

BASE_URL=http://localhost:8080
PS_FILE=docs/01-compose-ps.txt
CRUD_FILE=docs/02-crud.txt
PERSISTENCE_FILE=docs/03-persistence.txt
LOGS_FILE=docs/04-compose-logs.txt
PSQL=(docker compose exec -T db psql -U postgres -d app -c
  "SELECT id, title, completed, created_at, updated_at FROM tasks ORDER BY id;")

LAST=$(mktemp)
trap 'rm -f "$LAST"' EXIT

init_file() {
  echo "# $2 ($(date '+%Y-%m-%d %H:%M:%S'))" | tee "$1"
}

# Runs a command and writes "> command" plus its stdout and stderr to the console and the file.
step() {
  local file=$1
  shift
  printf '\n> %s\n' "$*" | tee -a "$file"
  : > "$LAST"
  "$@" 2>&1 | tee -a "$file" "$LAST"
}

api() {
  local file=$1 method=$2 path=$3 body=${4:-}
  if [ -n "$body" ]; then
    step "$file" curl -s -i -X "$method" -H "Content-Type: application/json" -d "@$body" "$BASE_URL$path"
  else
    step "$file" curl -s -i -X "$method" "$BASE_URL$path"
  fi
}

created_id() {
  local id
  id=$(tail -n 1 "$LAST" | grep -o '"id":[0-9]*' | head -n 1 | cut -d: -f2)
  if [ -z "$id" ]; then
    echo "POST /tasks did not return a created task, stopping." >&2
    exit 1
  fi
  echo "$id"
}

wait_api() {
  echo "Waiting for API at $BASE_URL/health ..."
  for _ in $(seq 1 60); do
    if curl -sf "$BASE_URL/health" > /dev/null; then
      echo "API is ready"
      return 0
    fi
    sleep 2
  done
  echo "API did not become ready. Check: docker compose logs api" >&2
  exit 1
}

# 1. Start the stack and show running services
init_file "$PS_FILE" "docker compose up + docker compose ps"
step "$PS_FILE" docker compose up -d --build
wait_api
step "$PS_FILE" docker compose ps

# 2. CRUD: create two tasks, read, update the first, delete the second
init_file "$CRUD_FILE" "CRUD requests to the API"
api "$CRUD_FILE" GET /tasks
api "$CRUD_FILE" POST /tasks requests/create-task.json
FIRST_ID=$(created_id)
api "$CRUD_FILE" POST /tasks requests/create-task-2.json
SECOND_ID=$(created_id)
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
echo "Done. Results are saved to $(pwd)/docs"
