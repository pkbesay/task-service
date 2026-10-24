package com.example.taskservice;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.SQLException;

// GET /health - проверка, что API видит PostgreSQL. Скрипты verify ждут по нему старта API.
@RestController
public class HealthController {

    public record Health(String status, String database) {
    }

    private final DataSource dataSource;

    public HealthController(DataSource dataSource) {
        this.dataSource = dataSource;
    }

    @GetMapping("/health")
    public ResponseEntity<Health> health() {
        try (Connection connection = dataSource.getConnection()) {
            if (connection.isValid(2)) {
                return ResponseEntity.ok(new Health("ok", "connected"));
            }
        } catch (SQLException ignored) {
            // БД недоступна - отвечаем 503 ниже
        }
        return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).body(new Health("error", "unavailable"));
    }
}
