# Сервис задач: CRUD API + PostgreSQL в Docker Compose

API-приложение на **.NET 9** (ASP.NET Core Minimal API + Entity Framework Core) с CRUD для сущности «Задача».
База данных — **PostgreSQL 16**, запускается отдельным сервисом `db` в Docker Compose, данные хранятся в volume `db_data`.

```
              порт 8080 (хост)
                    │
┌───────────────────▼──────┐   сеть app-network   ┌───────────────────────────┐
│ api  (.NET 9, Dockerfile)│ ───────────────────► │ db  (postgres:16)         │
│ DB_HOST=db, DB_PORT=5432 │   Host=db;Port=5432  │ база app, user postgres   │
└──────────────────────────┘                      └─────────────┬─────────────┘
                                                                │
                                                  volume db_data → /var/lib/postgresql/data
```

## Тема и сущность

Тема проекта — **сервис задач** (трекер задач). Основная сущность — задача `TaskItem`, таблица `tasks`:

| Колонка        | Тип                  | Описание                          |
|----------------|----------------------|-----------------------------------|
| `id`           | integer, PK, identity | идентификатор задачи             |
| `title`        | varchar(200), NOT NULL | название (обязательное)         |
| `description`  | varchar(1000)        | описание                          |
| `is_completed` | boolean              | выполнена ли задача               |
| `created_at`   | timestamptz          | когда создана                     |
| `updated_at`   | timestamptz          | когда последний раз изменялась    |

## Эндпоинты

| Метод    | URL           | Действие                              | Ответ                     |
|----------|---------------|---------------------------------------|---------------------------|
| `GET`    | `/tasks`      | Read — список всех задач              | 200                       |
| `GET`    | `/tasks/{id}` | Read — одна задача                    | 200 / 404                 |
| `POST`   | `/tasks`      | Create — создать задачу               | 201 + `Location` / 400    |
| `PUT`    | `/tasks/{id}` | Update — изменить задачу              | 200 / 400 / 404           |
| `DELETE` | `/tasks/{id}` | Delete — удалить задачу               | 204 / 404                 |
| `GET`    | `/health`     | проверка, что API видит PostgreSQL    | 200 / 503                 |

Тело запроса для `POST` и `PUT`:

```json
{ "title": "Prepare weekly report", "description": "Collect team results", "isCompleted": false }
```

## Структура проекта

```
.
├── docker-compose.yml          # сервисы api и db, сеть, volume db_data
├── TaskApi/
│   ├── Dockerfile              # многоэтапная сборка образа API
│   ├── .dockerignore
│   ├── TaskApi.csproj
│   ├── Program.cs              # подключение к БД из env, CRUD-эндпоинты
│   ├── Data/AppDbContext.cs    # EF Core: таблица tasks
│   ├── Models/TaskItem.cs      # сущность и модель запроса
│   └── appsettings.json
├── requests/                   # JSON-тела для curl-запросов
├── postman/TaskService.postman_collection.json
├── scripts/
│   ├── verify.ps1              # автоматическая проверка (Windows)
│   └── verify.sh               # автоматическая проверка (Linux/macOS)
└── docs/                       # выводы проверок (создаются скриптом verify)
```

## Docker Compose

**Сервисы:**

- `db` — образ `postgres:16`. Healthcheck `pg_isready` каждые 5 секунд. Порт 5432 на хост не публикуется: API обращается к БД по внутренней сети, поэтому не будет конфликта с локально установленным PostgreSQL.
- `api` — собирается из `TaskApi/Dockerfile`, публикует порт `8080:8080`. Благодаря `depends_on: condition: service_healthy` стартует только после того, как `db` пройдёт healthcheck. Дополнительно API при старте делает до 10 попыток подключения к БД.

**Переменные окружения (`environment`):**

| Сервис | Переменная          | Значение     | Назначение                                  |
|--------|---------------------|--------------|---------------------------------------------|
| db     | `POSTGRES_DB`       | `app`        | база, которая создаётся при первом запуске  |
| db     | `POSTGRES_USER`     | `postgres`   | пользователь                                |
| db     | `POSTGRES_PASSWORD` | `1234`       | пароль                                      |
| api    | `DB_HOST`           | `db`         | хост БД — **имя сервиса** из compose        |
| api    | `DB_PORT`           | `5432`       | порт PostgreSQL внутри сети                 |
| api    | `DB_NAME`           | `app`        | имя базы                                    |
| api    | `DB_USER`           | `postgres`   | пользователь                                |
| api    | `DB_PASSWORD`       | `1234`       | пароль                                      |
| api    | `ASPNETCORE_HTTP_PORTS` | `8080`   | порт, который слушает API в контейнере      |

Из этих переменных API собирает строку подключения `Host=db;Port=5432;Database=app;Username=postgres;Password=1234` (`TaskApi/Program.cs`).

**Сеть:** `app-network` (bridge). Внутри неё работает DNS Docker, поэтому имя `db` превращается в IP-адрес контейнера с PostgreSQL.

**Volume:** `db_data` смонтирован в `/var/lib/postgresql/data`, где PostgreSQL хранит файлы базы. `docker compose down` удаляет контейнеры, но не volume, поэтому после `docker compose up` данные остаются на месте. Полное имя volume — `task-service_db_data` (проект называется `task-service`, это задано в `name:` в compose-файле).

Таблица `tasks` создаётся API при первом запуске (`EnsureCreated`). При следующих запусках API видит, что таблица уже есть, и данные не трогает.

## Требования

- Docker Desktop (Windows/macOS) или Docker Engine с плагином Docker Compose;
- свободный порт 8080 на хосте. Если он занят, поменяйте в `docker-compose.yml` `"8080:8080"` на, например, `"8081:8080"` и используйте `http://localhost:8081`.

.NET SDK для запуска через Docker не нужен: сборка идёт внутри образа `mcr.microsoft.com/dotnet/sdk:9.0`.

## Запуск

```bash
docker compose up -d --build
```

Проверить, что оба сервиса запущены (`db` должен быть `healthy`):

```bash
docker compose ps
```

Чтобы видеть логи прямо в консоли, запускайте без `-d`: `docker compose up --build`.

## Проверка CRUD через curl

В Windows PowerShell пишите `curl.exe`, а не `curl`: в PowerShell 5.1 `curl` — это псевдоним `Invoke-WebRequest`. Тела запросов берутся из файлов в `requests/`, поэтому одни и те же команды работают и в PowerShell, и в bash без проблем с кавычками. Выполняйте их из корня проекта.

```bash
# Create: создать две задачи
curl -i -X POST -H "Content-Type: application/json" -d @requests/create-task.json http://localhost:8080/tasks
curl -i -X POST -H "Content-Type: application/json" -d @requests/create-task-2.json http://localhost:8080/tasks

# Read: список и одна задача
curl -i http://localhost:8080/tasks
curl -i http://localhost:8080/tasks/1

# Update: отметить задачу 1 выполненной
curl -i -X PUT -H "Content-Type: application/json" -d @requests/update-task.json http://localhost:8080/tasks/1

# Delete: удалить задачу 2, затем убедиться, что её нет (404)
curl -i -X DELETE http://localhost:8080/tasks/2
curl -i http://localhost:8080/tasks/2
```

Тот же запрос с JSON прямо в команде (bash, Git Bash, macOS/Linux):

```bash
curl -i -X POST http://localhost:8080/tasks -H "Content-Type: application/json" \
  -d '{"title":"Buy milk","description":"2 liters","isCompleted":false}'
```

Посмотреть данные прямо в PostgreSQL:

```bash
docker compose exec db psql -U postgres -d app -c "SELECT * FROM tasks ORDER BY id;"
```

## Проверка сохранения данных после перезапуска

```bash
docker compose down
docker volume ls --filter name=db_data
docker compose up -d
curl -i http://localhost:8080/tasks
docker compose exec db psql -U postgres -d app -c "SELECT * FROM tasks ORDER BY id;"
```

После `down` volume `task-service_db_data` остаётся в списке, а после `up` `GET /tasks` возвращает те же задачи, что были до перезапуска.

> `docker compose down -v` удаляет и volume, то есть все данные. Используйте это только если нужно начать с пустой базы.

## Логи

```bash
docker compose logs            # все сервисы
docker compose logs api        # только API
docker compose logs -f         # следить в реальном времени
```

На что смотреть:

- `db`: `database system is ready to accept connections`; после перезапуска — `PostgreSQL Database directory appears to contain a database; Skipping initialization` (база взята из volume);
- `api`: `Connecting to PostgreSQL at db:5432, database 'app'`, затем `table 'tasks' created` при первом запуске или `table 'tasks' already exists - existing data is kept` после перезапуска;
- `api`: строка на каждый запрос, например `POST /tasks -> 201`, и SQL-команды EF Core (`INSERT INTO tasks ...`, `UPDATE tasks ...`, `DELETE FROM tasks ...`).

## Автоматическая проверка одной командой

Скрипт проходит все пункты проверки и сохраняет вывод в `docs/`.

Windows (PowerShell):

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify.ps1
```

Linux / macOS:

```bash
bash scripts/verify.sh
```

Что делает скрипт: `docker compose up -d --build` → ждёт `/health` → `docker compose ps` → CRUD-запросы (создать 2 задачи, прочитать, обновить первую, удалить вторую, проверить 404) → `SELECT` из PostgreSQL → `docker compose logs` → `docker compose down` → `docker volume ls` → `docker compose up -d` → снова `GET /tasks` и `SELECT` → логи после перезапуска.

| Файл                        | Что в нём                                                     |
|-----------------------------|---------------------------------------------------------------|
| `docs/01-compose-ps.txt`    | вывод `docker compose up` и `docker compose ps`               |
| `docs/02-crud.txt`          | все CRUD-запросы с ответами и `SELECT` из таблицы `tasks`     |
| `docs/03-persistence.txt`   | `down` → volume на месте → `up` → данные сохранились          |
| `docs/04-compose-logs.txt`  | `docker compose logs` до и после перезапуска                  |

Эти файлы — текстовые подтверждения для сдачи работы. Скриншоты можно положить рядом, в `docs/screenshots/`.

## Postman

Импортируйте `postman/TaskService.postman_collection.json` (File → Import). Переменная `baseUrl` = `http://localhost:8080`. Запросы удобно запускать по порядку через Collection Runner: `Create task` сохраняет id созданной задачи в переменную `taskId`, а `Get task by id`, `Update task` и `Delete task` используют его.

## Остановка

```bash
docker compose down        # остановить, данные сохранятся
docker compose down -v     # остановить и удалить данные
```

## Шпаргалка для защиты

- **Сущность:** задача (`TaskItem`, таблица `tasks`): название, описание, признак выполнения, даты создания и изменения.
- **Связь с темой:** проект — сервис задач, задача — его основной объект. CRUD покрывает весь её жизненный цикл: создать, посмотреть, отметить выполненной или изменить, удалить.
- **Сервисы в compose:** `api` (наше .NET-приложение, собирается из Dockerfile) и `db` (официальный образ `postgres:16`).
- **Почему PostgreSQL:** полноценная серверная СУБД, работает отдельным процессом и отдельным контейнером, хранит данные в своей папке, которую можно вынести в volume. SQLite — это файл внутри процесса приложения, отдельным сервисом её не запустить.
- **Как API подключается к db:** в `DB_HOST` передаётся имя сервиса `db`. Оба контейнера в сети `app-network`, встроенный DNS Docker превращает `db` в IP контейнера PostgreSQL. `depends_on` с `service_healthy` гарантирует, что API стартует после готовности БД.
- **Переменные окружения:** `POSTGRES_DB/USER/PASSWORD` для инициализации базы; `DB_HOST/PORT/NAME/USER/PASSWORD` для строки подключения API — настройки не зашиты в код.
- **Volume `db_data`:** смонтирован в `/var/lib/postgresql/data`, живёт отдельно от контейнера, поэтому `docker compose down` + `up` не теряет данные.
- **Как проверялось:** curl-запросами (или Postman) прошли Create/Read/Update/Delete, данные проверены через `psql` в контейнере `db`; затем `docker compose down` → `up`, и `GET /tasks` вернул те же записи. Всё это есть в `docs/*.txt` и в `docker compose logs`.
