CREATE TABLE IF NOT EXISTS shipping_addresses (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES member(id) ON DELETE CASCADE,
    recipient_name VARCHAR(255) NOT NULL,
    phone_number VARCHAR(50) NOT NULL,
    address_line1 TEXT NOT NULL,
    sub_district VARCHAR(100),
    district VARCHAR(100),
    province VARCHAR(100),
    postal_code VARCHAR(20),
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_shipping_addresses_user_id ON shipping_addresses(user_id);
