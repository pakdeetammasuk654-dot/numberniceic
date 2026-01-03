CREATE TABLE promotional_codes (
    id SERIAL PRIMARY KEY,
    code VARCHAR(50) UNIQUE NOT NULL,
    is_used BOOLEAN DEFAULT FALSE,
    used_by_member_id INT REFERENCES member(id),
    used_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);
