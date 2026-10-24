# Shared helpers for verify-docker.sh and verify-compose.sh.
# Those scripts source this file; it is not meant to be run on its own.

cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
BASE_URL=http://localhost:8080

LAST=$(mktemp)
trap 'rm -f "$LAST"' EXIT

init_file() {
  mkdir -p "$(dirname "$1")"
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

# Prints the id from the last POST response; call as: ID=$(created_id) || exit 1
created_id() {
  local id
  id=$(tail -n 1 "$LAST" | grep -o '"id":[0-9]*' | head -n 1 | cut -d: -f2)
  if [ -z "$id" ]; then
    echo "POST /tasks did not return a created task, stopping." >&2
    return 1
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
  echo "API did not become ready. Check the logs: docker logs task-api / docker compose logs api" >&2
  exit 1
}
