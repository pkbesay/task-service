using Microsoft.EntityFrameworkCore;
using TaskApi.Models;

namespace TaskApi.Data;

public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<TaskItem> Tasks => Set<TaskItem>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        // Явные имена таблицы и колонок в snake_case, чтобы было удобно смотреть данные через psql.
        var task = modelBuilder.Entity<TaskItem>();
        task.ToTable("tasks");
        task.HasKey(t => t.Id);
        task.Property(t => t.Id).HasColumnName("id");
        task.Property(t => t.Title).HasColumnName("title").HasMaxLength(200).IsRequired();
        task.Property(t => t.Description).HasColumnName("description").HasMaxLength(1000);
        task.Property(t => t.IsCompleted).HasColumnName("is_completed");
        task.Property(t => t.CreatedAt).HasColumnName("created_at");
        task.Property(t => t.UpdatedAt).HasColumnName("updated_at");
    }
}
