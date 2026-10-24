using Microsoft.EntityFrameworkCore;
using Npgsql;
using TaskApi.Data;
using TaskApi.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Logging.AddSimpleConsole(options =>
{
    options.SingleLine = true;
    options.TimestampFormat = "yyyy-MM-dd HH:mm:ss ";
});

// Параметры подключения приходят из переменных окружения (секция environment в docker-compose.yml).
// DB_HOST=db — имя сервиса PostgreSQL в docker-compose: Docker DNS сам находит IP контейнера по этому имени.
var connection = new NpgsqlConnectionStringBuilder
{
    Host = builder.Configuration["DB_HOST"] ?? "localhost",
    Port = int.Parse(builder.Configuration["DB_PORT"] ?? "5432"),
    Database = builder.Configuration["DB_NAME"] ?? "app",
    Username = builder.Configuration["DB_USER"] ?? "postgres",
    Password = builder.Configuration["DB_PASSWORD"] ?? "1234",
};

builder.Services.AddDbContext<AppDbContext>(options => options.UseNpgsql(connection.ConnectionString));

var app = builder.Build();

app.Logger.LogInformation("Connecting to PostgreSQL at {Host}:{Port}, database '{Database}'",
    connection.Host, connection.Port, connection.Database);
await EnsureDatabaseAsync(app);

// Каждый запрос пишется в лог, чтобы CRUD-проверка была видна в docker compose logs.
app.Use(async (context, next) =>
{
    await next();
    app.Logger.LogInformation("{Method} {Path} -> {StatusCode}",
        context.Request.Method, context.Request.Path, context.Response.StatusCode);
});

app.MapGet("/", () => Results.Ok(new
{
    service = "Task Service API",
    endpoints = new[] { "GET /tasks", "GET /tasks/{id}", "POST /tasks", "PUT /tasks/{id}", "DELETE /tasks/{id}", "GET /health" },
}));

app.MapGet("/health", async (AppDbContext db) =>
    await db.Database.CanConnectAsync()
        ? Results.Ok(new { status = "ok", database = "connected" })
        : Results.Json(new { status = "error", database = "unavailable" }, statusCode: 503));

var tasks = app.MapGroup("/tasks");

// Read: все задачи
tasks.MapGet("/", async (AppDbContext db) =>
    await db.Tasks.AsNoTracking().OrderBy(t => t.Id).ToListAsync());

// Read: одна задача
tasks.MapGet("/{id:int}", async (int id, AppDbContext db) =>
    await db.Tasks.FindAsync(id) is { } task
        ? Results.Ok(task)
        : TaskNotFound(id));

// Create
tasks.MapPost("/", async (TaskRequest request, AppDbContext db) =>
{
    if (Validate(request) is { } error) return error;

    var task = new TaskItem
    {
        Title = request.Title!.Trim(),
        Description = request.Description,
        IsCompleted = request.IsCompleted,
        CreatedAt = DateTime.UtcNow,
    };
    db.Tasks.Add(task);
    await db.SaveChangesAsync();
    return Results.Created($"/tasks/{task.Id}", task);
});

// Update
tasks.MapPut("/{id:int}", async (int id, TaskRequest request, AppDbContext db) =>
{
    if (Validate(request) is { } error) return error;

    var task = await db.Tasks.FindAsync(id);
    if (task is null) return TaskNotFound(id);

    task.Title = request.Title!.Trim();
    task.Description = request.Description;
    task.IsCompleted = request.IsCompleted;
    task.UpdatedAt = DateTime.UtcNow;
    await db.SaveChangesAsync();
    return Results.Ok(task);
});

// Delete
tasks.MapDelete("/{id:int}", async (int id, AppDbContext db) =>
{
    var task = await db.Tasks.FindAsync(id);
    if (task is null) return TaskNotFound(id);

    db.Tasks.Remove(task);
    await db.SaveChangesAsync();
    return Results.NoContent();
});

app.Run();

static IResult TaskNotFound(int id) =>
    Results.NotFound(new { error = $"Task {id} not found" });

static IResult? Validate(TaskRequest request)
{
    if (string.IsNullOrWhiteSpace(request.Title))
        return Results.BadRequest(new { error = "Field 'title' is required" });
    if (request.Title.Trim().Length > 200)
        return Results.BadRequest(new { error = "Field 'title' must be at most 200 characters" });
    return null;
}

// Контейнер db может ещё не принимать подключения — повторяем попытки, затем создаём
// таблицу tasks, если её нет. Существующие данные из volume db_data не трогаются.
static async Task EnsureDatabaseAsync(WebApplication app)
{
    const int maxAttempts = 10;
    using var scope = app.Services.CreateScope();
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();

    for (var attempt = 1; ; attempt++)
    {
        try
        {
            var created = await db.Database.EnsureCreatedAsync();
            app.Logger.LogInformation(created
                ? "Connected to PostgreSQL, table 'tasks' created"
                : "Connected to PostgreSQL, table 'tasks' already exists - existing data is kept");
            return;
        }
        catch (Exception ex) when (attempt < maxAttempts)
        {
            app.Logger.LogWarning("PostgreSQL is not ready (attempt {Attempt}/{MaxAttempts}): {Message}",
                attempt, maxAttempts, ex.Message);
            await Task.Delay(TimeSpan.FromSeconds(3));
        }
    }
}
