-- Constants-first migration: schema plus seed constants in one pair.
CREATE TABLE app_constants (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
INSERT INTO app_constants (key, value) VALUES ('greeting', 'hello');
