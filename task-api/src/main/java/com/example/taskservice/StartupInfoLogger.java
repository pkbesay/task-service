package com.example.taskservice;

import com.example.taskservice.task.TaskRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;

// При старте пишет в лог, к какой БД подключились и сколько задач уже лежит в таблице.
// После docker compose down / up здесь видно, что данные из volume db_data сохранились.
@Component
public class StartupInfoLogger implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(StartupInfoLogger.class);

    private final TaskRepository repository;
    private final String datasourceUrl;

    public StartupInfoLogger(TaskRepository repository, @Value("${spring.datasource.url}") String datasourceUrl) {
        this.repository = repository;
        this.datasourceUrl = datasourceUrl;
    }

    @Override
    public void run(ApplicationArguments args) {
        log.info("Connected to PostgreSQL at {}, table 'tasks' contains {} task(s)", datasourceUrl, repository.count());
    }
}
