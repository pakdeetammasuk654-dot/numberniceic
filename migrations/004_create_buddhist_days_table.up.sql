CREATE TABLE IF NOT EXISTS buddhist_days (
    id SERIAL PRIMARY KEY,
    date DATE NOT NULL UNIQUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_buddhist_days_date ON buddhist_days(date);
