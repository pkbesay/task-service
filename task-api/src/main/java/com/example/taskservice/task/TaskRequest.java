package com.example.taskservice.task;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

// Тело запроса для POST /tasks и PUT /tasks/{id}.
public record TaskRequest(
        @NotBlank(message = "Field 'title' is required")
        @Size(max = 200, message = "Field 'title' must be at most 200 characters")
        String title,

        @Size(max = 1000, message = "Field 'description' must be at most 1000 characters")
        String description,

        boolean completed) {
}
