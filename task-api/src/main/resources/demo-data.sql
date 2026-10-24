-- Демо-задачи для профиля standalone (H2 в памяти). С PostgreSQL этот файл не используется.
INSERT INTO tasks (title, description, completed, created_at) VALUES
    ('Install Docker Desktop', 'Needed to build and run the API container', true, CURRENT_TIMESTAMP),
    ('Write README', 'Describe build, run and check commands', false, CURRENT_TIMESTAMP);
