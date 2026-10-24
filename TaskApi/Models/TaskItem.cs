namespace TaskApi.Models;

// Сущность "Задача" — хранится в таблице tasks в PostgreSQL.
public class TaskItem
{
    public int Id { get; set; }
    public string Title { get; set; } = string.Empty;
    public string? Description { get; set; }
    public bool IsCompleted { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
}

// Тело запроса для POST /tasks и PUT /tasks/{id}.
public record TaskRequest(string? Title, string? Description, bool IsCompleted);
