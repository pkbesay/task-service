package com.example.taskservice.task;

import jakarta.validation.Valid;
import org.springframework.data.domain.Sort;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.net.URI;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;

@RestController
@RequestMapping("/tasks")
public class TaskController {

    private final TaskRepository repository;

    public TaskController(TaskRepository repository) {
        this.repository = repository;
    }

    // Read: все задачи
    @GetMapping
    public List<Task> getAll() {
        return repository.findAll(Sort.by("id"));
    }

    // Read: одна задача
    @GetMapping("/{id}")
    public Task getById(@PathVariable long id) {
        return findTask(id);
    }

    // Create
    @PostMapping
    public ResponseEntity<Task> create(@Valid @RequestBody TaskRequest request) {
        Task task = new Task();
        apply(task, request);
        task.setCreatedAt(now());
        Task saved = repository.save(task);
        return ResponseEntity.created(URI.create("/tasks/" + saved.getId())).body(saved);
    }

    // Update
    @PutMapping("/{id}")
    public Task update(@PathVariable long id, @Valid @RequestBody TaskRequest request) {
        Task task = findTask(id);
        apply(task, request);
        task.setUpdatedAt(now());
        return repository.save(task);
    }

    // Delete
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable long id) {
        repository.delete(findTask(id));
        return ResponseEntity.noContent().build();
    }

    private Task findTask(long id) {
        return repository.findById(id).orElseThrow(() -> new TaskNotFoundException(id));
    }

    private static void apply(Task task, TaskRequest request) {
        task.setTitle(request.title().trim());
        task.setDescription(request.description());
        task.setCompleted(request.completed());
    }

    // PostgreSQL хранит время с точностью до микросекунд - обрезаем сразу, чтобы ответы POST и GET совпадали
    private static Instant now() {
        return Instant.now().truncatedTo(ChronoUnit.MICROS);
    }
}
