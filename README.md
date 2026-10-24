# Сервис задач: Java API в Docker

API-приложение на **Java 21 + Spring Boot 3.5** (Spring Web, Spring Data JPA / Hibernate, Maven) с CRUD для сущности «Задача».
В одном репозитории собраны две контрольные точки — обе на одном и том же приложении и одном Dockerfile:

| Контрольная точка | Что показывает | Автопроверка | Подтверждения |
|-------------------|----------------|--------------|---------------|
| [КТ 1. API в Docker-контейнере](#кт-1-api-в-docker-контейнере) | Dockerfile → `docker build` → `docker run -p 8080:8080` → запрос к API, `docker ps`, `docker logs` | `scripts/verify-docker.ps1` | `docs/docker/` |
| [КТ 2. Docker Compose + PostgreSQL](#кт-2-docker-compose--postgresql) | сервисы `api` + `db` (postgres:16), переменные окружения, сеть, volume `db_data`, CRUD, сохранение данных после перезапуска | `scripts/verify-compose.ps1` | `docs/compose/` |

**Режимы работы API** (Spring-профили):

| Профиль | Где хранятся данные | Для чего |
|---------|---------------------|----------|
| по умолчанию | PostgreSQL, подключение из переменных `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD` | КТ 2, `docker compose` |
| `standalone` (`SPRING_PROFILES_ACTIVE=standalone`) | встроенная БД H2 в памяти, при старте две демо-задачи; данные пропадают при остановке | КТ 1: один контейнер без внешней БД; проверка API локально без Docker |

## Тема и сущность

Тема проекта — **сервис задач** (трекер задач). Основная сущность — задача `Task`, таблица `tasks`:

| Колонка       | Тип                         | Описание                         |
|---------------|-----------------------------|----------------------------------|
| `id`          | bigint, PK, identity        | идентификатор задачи             |
| `title`       | varchar(200), NOT NULL      | название (обязательное)          |
| `description` | varchar(1000)               | описание                         |
| `completed`   | boolean, NOT NULL           | выполнена ли задача              |
| `created_at`  | timestamp with time zone    | когда создана                    |
| `updated_at`  | timestamp with time zone    | когда последний раз изменялась   |

## Эндпоинты

| Метод    | URL           | Действие                              | Ответ                     |
|----------|---------------|---------------------------------------|---------------------------|
| `GET`    | `/tasks`      | Read — список всех задач              | 200                       |
| `GET`    | `/tasks/{id}` | Read — одна задача                    | 200 / 404                 |
| `POST`   | `/tasks`      | Create — создать задачу               | 201 + `Location` / 400    |
| `PUT`    | `/tasks/{id}` | Update — изменить задачу              | 200 / 400 / 404           |
| `DELETE` | `/tasks/{id}` | Delete — удалить задачу               | 204 / 404                 |
| `GET`    | `/health`     | проверка, что API видит свою БД       | 200 / 503                 |

Тело запроса для `POST` и `PUT`:

```json
{ "title": "Prepare weekly report", "description": "Collect team results", "completed": false }
```

## Структура проекта

```
.
├── docker-compose.yml                  # КТ 2: сервисы api и db, сеть, volume db_data
├── task-api/
│   ├── Dockerfile                      # написан вручную: Maven + JDK 21 → JRE 21
│   ├── .dockerignore
│   ├── pom.xml                         # Spring Boot 3.5, web, data-jpa, validation, драйверы PostgreSQL и H2
│   └── src/main/
│       ├── resources/
│       │   ├── application.properties             # по умолчанию: PostgreSQL из переменных окружения
│       │   ├── application-standalone.properties  # профиль standalone: H2 в памяти
│       │   └── demo-data.sql                      # демо-задачи для standalone
│       └── java/com/example/taskservice/
│           ├── TaskServiceApplication.java    # точка входа
│           ├── task/Task.java                 # сущность JPA → таблица tasks
│           ├── task/TaskRequest.java          # тело запроса + валидация
│           ├── task/TaskRepository.java       # Spring Data JPA репозиторий
│           ├── task/TaskController.java       # CRUD-эндпоинты /tasks
│           ├── task/TaskNotFoundException.java
│           ├── ApiExceptionHandler.java       # 400 / 404 в виде {"error": "..."}
│           ├── HealthController.java          # GET /health
│           ├── RequestLoggingFilter.java      # строка в логе на каждый запрос
│           └── StartupInfoLogger.java         # при старте: к какой БД подключились и сколько задач
├── requests/                           # JSON-тела для curl-запросов
├── postman/TaskService.postman_collection.json
├── scripts/
│   ├── verify-docker.ps1 / .sh         # автопроверка КТ 1
│   ├── verify-compose.ps1 / .sh        # автопроверка КТ 2
│   └── common.ps1 / .sh                # общие функции скриптов
└── docs/
    ├── docker/                         # выводы проверки КТ 1 (создаёт verify-docker)
    └── compose/                        # выводы проверки КТ 2 (создаёт verify-compose)
```

## Требования

- Docker Desktop (Windows/macOS) или Docker Engine с плагином Docker Compose;
- свободный порт 8080 на хосте. Если на нём уже что-то работает (например, Apache из XAMPP), остановите это на время проверки — иначе `docker run -p 8080:8080` завершится ошибкой `port is already allocated`;
- для запуска без Docker — JDK 21+ и Maven, либо IntelliJ IDEA.

В Windows PowerShell пишите `curl.exe`, а не `curl`: в PowerShell 5.1 `curl` — это псевдоним `Invoke-WebRequest`. Тела запросов берутся из файлов в `requests/`, поэтому одни и те же команды работают и в PowerShell, и в bash. Выполняйте их из корня проекта.

---

## КТ 1. API в Docker-контейнере

Схема: `API → Dockerfile → docker build → docker run -p 8080:8080 → запрос к API`.

### 1. Проверка API локально без Docker

API запускается в профиле `standalone`, внешняя БД не нужна:

```bash
cd task-api
mvn spring-boot:run -Dspring-boot.run.profiles=standalone
```

В IntelliJ IDEA: открыть папку `task-api` как Maven-проект, запустить `TaskServiceApplication`, в Run Configuration указать **Active profiles: `standalone`**.

Проверка — в браузере http://localhost:8080/tasks или:

```bash
curl -i http://localhost:8080/health
curl -i http://localhost:8080/tasks
```

### 2. Dockerfile

Файл `task-api/Dockerfile` написан вручную, сборка в два этапа:

```dockerfile
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /src
COPY pom.xml ./
RUN mvn -B -ntp dependency:go-offline
COPY src ./src
RUN mvn -B -ntp package -DskipTests

FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /src/target/task-api.jar ./app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```

| Инструкция | Зачем |
|------------|-------|
| `FROM maven:3.9-eclipse-temurin-21 AS build` | первый этап — образ с Maven и JDK 21, нужен только для сборки |
| `WORKDIR /src` | рабочая папка внутри образа, дальше все пути относительно неё |
| `COPY pom.xml ./` + `RUN mvn dependency:go-offline` | сначала копируем только `pom.xml` и скачиваем зависимости — этот слой кешируется и не пересобирается, пока не меняется `pom.xml` |
| `COPY src ./src` + `RUN mvn package -DskipTests` | копируем исходники и собираем исполняемый `task-api.jar` |
| `FROM eclipse-temurin:21-jre` | второй этап — лёгкий образ только с JRE, без Maven и исходников |
| `COPY --from=build … ./app.jar` | берём готовый jar из первого этапа |
| `EXPOSE 8080` | документирует, что приложение слушает порт 8080 |
| `ENTRYPOINT ["java", "-jar", "app.jar"]` | команда, которая запускается при старте контейнера |

### 3. Сборка образа

```bash
docker build -t task-api ./task-api
```

`-t task-api` — имя образа, `./task-api` — контекст сборки (папка с Dockerfile). Первая сборка занимает пару минут: Maven скачивает зависимости.

### 4. Запуск контейнера с пробросом порта

```bash
docker run -d --name task-api -p 8080:8080 -e SPRING_PROFILES_ACTIVE=standalone task-api
```

- `-p 8080:8080` — порт **хоста** 8080 → порт **контейнера** 8080, поэтому API доступно снаружи по `http://localhost:8080`;
- `-e SPRING_PROFILES_ACTIVE=standalone` — профиль без PostgreSQL (H2 в памяти);
- `-d` — запуск в фоне, `--name task-api` — имя контейнера для `docker ps` / `docker logs`.

### 5. Контейнер в списке запущенных

```bash
docker ps
```

У контейнера `task-api` должны быть `STATUS` = `Up …` и `PORTS` = `0.0.0.0:8080->8080/tcp`.

### 6. Запрос к API

В браузере: http://localhost:8080/tasks (две демо-задачи) и http://localhost:8080/health. Или через curl:

```bash
curl -i http://localhost:8080/health
curl -i http://localhost:8080/tasks
curl -i -X POST -H "Content-Type: application/json" -d @requests/create-task.json http://localhost:8080/tasks
curl -i http://localhost:8080/tasks/3
```

Или через Postman — см. раздел [Postman](#postman).

### 7. Логи контейнера

```bash
docker logs task-api
```

На что смотреть: `The following 1 profile is active: "standalone"`, `Tomcat started on port 8080`, `Started TaskServiceApplication in … seconds`, `Connected to database jdbc:h2:mem:tasks…, table 'tasks' contains 2 task(s)` и строка на каждый запрос, например `GET /tasks -> 200`, `POST /tasks -> 201`.

### 8. Остановка

```bash
docker rm -f task-api
```

### Автоматическая проверка КТ 1

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-docker.ps1
```

Linux / macOS: `bash scripts/verify-docker.sh`.

Скрипт освобождает порт 8080 (`docker compose down`, данные в volume сохраняются), выполняет шаги 3–7 и оставляет контейнер запущенным, чтобы можно было показать API в браузере.

| Файл                              | Что в нём                                         |
|-----------------------------------|---------------------------------------------------|
| `docs/docker/01-docker-build.txt` | вывод `docker build`                              |
| `docs/docker/02-docker-run-ps.txt`| `docker run -p 8080:8080 …` и `docker ps`         |
| `docs/docker/03-api-requests.txt` | запросы к API из-за пределов контейнера с ответами |
| `docs/docker/04-docker-logs.txt`  | вывод `docker logs task-api`                      |

---

## КТ 2. Docker Compose + PostgreSQL

```
              порт 8080 (хост)
                    │
┌───────────────────▼──────────┐  сеть app-network  ┌───────────────────────────┐
│ api  (Java 21, Spring Boot)  │ ─────────────────► │ db  (postgres:16)         │
│ DB_HOST=db, DB_PORT=5432     │ jdbc:postgresql:// │ база app, user postgres   │
└──────────────────────────────┘    db:5432/app     └─────────────┬─────────────┘
                                                                  │
                                                    volume db_data → /var/lib/postgresql/data
```

### Сервисы

- `db` — образ `postgres:16`. Healthcheck `pg_isready` каждые 5 секунд. Порт 5432 на хост не публикуется: API обращается к БД по внутренней сети, поэтому не будет конфликта с локально установленным PostgreSQL.
- `api` — собирается из того же `task-api/Dockerfile`, публикует порт `8080:8080`. Профиль не задаётся, то есть используется PostgreSQL. Благодаря `depends_on: condition: service_healthy` стартует только после того, как `db` пройдёт healthcheck. Дополнительно пул подключений Hikari при старте до 60 секунд повторяет попытки подключиться к БД.

### Переменные окружения (`environment`)

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

В `task-api/src/main/resources/application.properties` из них собирается подключение:

```properties
spring.datasource.url=jdbc:postgresql://${DB_HOST:localhost}:${DB_PORT:5432}/${DB_NAME:app}
spring.datasource.username=${DB_USER:postgres}
spring.datasource.password=${DB_PASSWORD:1234}
```

### Сеть и volume

**Сеть:** `app-network` (bridge). Внутри неё работает DNS Docker, поэтому имя `db` превращается в IP-адрес контейнера с PostgreSQL.

**Volume:** `db_data` смонтирован в `/var/lib/postgresql/data`, где PostgreSQL хранит файлы базы. `docker compose down` удаляет контейнеры, но не volume, поэтому после `docker compose up` данные остаются на месте. Полное имя volume — `task-service_db_data` (проект называется `task-service`, это задано в `name:` в compose-файле).

Таблицу `tasks` создаёт Hibernate при первом запуске (`spring.jpa.hibernate.ddl-auto=update`). При следующих запусках таблица уже есть, и данные не трогаются.

### Запуск

Если запущен контейнер из КТ 1, сначала остановите его (`docker rm -f task-api`) — он занимает порт 8080.

```bash
docker compose up -d --build
docker compose ps
```

`db` должен быть `healthy`, `api` — `Up`. Чтобы видеть логи прямо в консоли, запускайте без `-d`: `docker compose up --build`.

### Проверка CRUD

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
  -d '{"title":"Buy milk","description":"2 liters","completed":false}'
```

Посмотреть данные прямо в PostgreSQL:

```bash
docker compose exec db psql -U postgres -d app -c "SELECT * FROM tasks ORDER BY id;"
```

### Сохранение данных после перезапуска

```bash
docker compose down
docker volume ls --filter name=db_data
docker compose up -d
curl -i http://localhost:8080/tasks
docker compose exec db psql -U postgres -d app -c "SELECT * FROM tasks ORDER BY id;"
```

После `down` volume `task-service_db_data` остаётся в списке, а после `up` `GET /tasks` возвращает те же задачи, что были до перезапуска.

> `docker compose down -v` удаляет и volume, то есть все данные. Используйте это только если нужно начать с пустой базы.

### Логи

```bash
docker compose logs            # все сервисы
docker compose logs api        # только API
docker compose logs -f         # следить в реальном времени
```

На что смотреть:

- `db`: `database system is ready to accept connections`; после перезапуска — `PostgreSQL Database directory appears to contain a database; Skipping initialization` (база взята из volume);
- `api`: `HikariPool-1 - Start completed` (подключились к PostgreSQL), `Started TaskServiceApplication in … seconds`;
- `api`: `Connected to database jdbc:postgresql://db:5432/app, table 'tasks' contains N task(s)` — после перезапуска N совпадает с числом задач до него;
- `api`: строка на каждый запрос, например `POST /tasks -> 201`, и SQL Hibernate (`insert into tasks …`, `update tasks …`, `delete from tasks …`).

### Автоматическая проверка КТ 2

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-compose.ps1
```

Linux / macOS: `bash scripts/verify-compose.sh`.

Что делает скрипт: `docker compose up -d --build` → ждёт `/health` → `docker compose ps` → CRUD-запросы (создать 2 задачи, прочитать, обновить первую, удалить вторую, проверить 404) → `SELECT` из PostgreSQL → `docker compose logs` → `docker compose down` → `docker volume ls` → `docker compose up -d` → снова `GET /tasks` и `SELECT` → логи после перезапуска.

| Файл                               | Что в нём                                                     |
|------------------------------------|---------------------------------------------------------------|
| `docs/compose/01-compose-ps.txt`   | вывод `docker compose up` и `docker compose ps`               |
| `docs/compose/02-crud.txt`         | все CRUD-запросы с ответами и `SELECT` из таблицы `tasks`     |
| `docs/compose/03-persistence.txt`  | `down` → volume на месте → `up` → данные сохранились          |
| `docs/compose/04-compose-logs.txt` | `docker compose logs` до и после перезапуска                  |

### Остановка

```bash
docker compose down        # остановить, данные сохранятся
docker compose down -v     # остановить и удалить данные
```

---

## Postman

Импортируйте `postman/TaskService.postman_collection.json` (File → Import). Переменная `baseUrl` = `http://localhost:8080`. Запросы удобно запускать по порядку через Collection Runner: `Create task` сохраняет id созданной задачи в переменную `taskId`, а `Get task by id`, `Update task` и `Delete task` используют его. Коллекция подходит для обеих КТ.

Скриншоты (Postman, браузер, `docker ps`) можно положить в `docs/docker/screenshots/` и `docs/compose/screenshots/`.

## Шпаргалка для защиты

### КТ 1. API в Docker-контейнере

- **Что делает API:** сервис задач — хранит задачи и даёт REST-доступ к ним. Основной endpoint по теме — `GET /tasks` (список задач), плюс полный CRUD и `GET /health`.
- **Связь с темой:** проект — сервис задач, `GET /tasks` отдаёт главный объект предметной области — задачи.
- **Dockerfile:** две стадии. Первая (`maven:3.9-eclipse-temurin-21`) — `COPY pom.xml`, `RUN mvn dependency:go-offline` (кеш зависимостей), `COPY src`, `RUN mvn package` → jar. Вторая (`eclipse-temurin:21-jre`) — `COPY --from=build` готового jar, `EXPOSE 8080`, `ENTRYPOINT ["java", "-jar", "app.jar"]`. Итоговый образ меньше: в нём нет Maven, JDK и исходников.
- **Сборка:** `docker build -t task-api ./task-api`.
- **Запуск:** `docker run -d --name task-api -p 8080:8080 -e SPRING_PROFILES_ACTIVE=standalone task-api` — порт 8080 хоста проброшен на порт 8080 контейнера; профиль `standalone` — встроенная H2 в памяти, чтобы один контейнер работал без PostgreSQL.
- **Проверка:** запрос `curl http://localhost:8080/tasks` (или браузер / Postman) снаружи контейнера, `docker ps` — контейнер `Up`, порт `0.0.0.0:8080->8080/tcp`, `docker logs task-api` — старт приложения и строки запросов. Всё это в `docs/docker/*.txt`.

### КТ 2. Docker Compose + PostgreSQL

- **Сущность:** задача (`Task`, таблица `tasks`): название, описание, признак выполнения, даты создания и изменения.
- **Связь с темой:** задача — основной объект сервиса задач. CRUD покрывает весь её жизненный цикл: создать, посмотреть, отметить выполненной или изменить, удалить.
- **Как устроен API:** `TaskController` (REST, `@RestController`) → `TaskRepository` (Spring Data JPA) → Hibernate → JDBC-драйвер PostgreSQL. Входные данные проверяются аннотациями `@NotBlank` / `@Size`, ошибки возвращаются как 400 / 404.
- **Сервисы в compose:** `api` (Spring Boot приложение, собирается из Dockerfile) и `db` (официальный образ `postgres:16`).
- **Почему PostgreSQL:** полноценная серверная СУБД, работает отдельным процессом и отдельным контейнером, хранит данные в своей папке, которую можно вынести в volume. SQLite — это файл внутри процесса приложения, отдельным сервисом её не запустить. (H2 используется только в профиле `standalone` для КТ 1, в compose её нет.)
- **Как API подключается к db:** в `DB_HOST` передаётся имя сервиса `db`, из него собирается `jdbc:postgresql://db:5432/app`. Оба контейнера в сети `app-network`, встроенный DNS Docker превращает `db` в IP контейнера PostgreSQL. `depends_on` с `service_healthy` гарантирует, что API стартует после готовности БД.
- **Переменные окружения:** `POSTGRES_DB/USER/PASSWORD` для инициализации базы; `DB_HOST/PORT/NAME/USER/PASSWORD` для подключения API — настройки не зашиты в код.
- **Volume `db_data`:** смонтирован в `/var/lib/postgresql/data`, живёт отдельно от контейнера, поэтому `docker compose down` + `up` не теряет данные.
- **Как проверялось:** curl-запросами (или Postman) прошли Create/Read/Update/Delete, данные проверены через `psql` в контейнере `db`; затем `docker compose down` → `up`, и `GET /tasks` вернул те же записи. Всё это есть в `docs/compose/*.txt` и в `docker compose logs`.
