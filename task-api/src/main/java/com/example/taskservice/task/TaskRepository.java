package com.example.taskservice.task;

import org.springframework.data.jpa.repository.JpaRepository;

// Spring Data сам реализует findAll, findById, save, delete и т.д. поверх таблицы tasks.
public interface TaskRepository extends JpaRepository<Task, Long> {
}
