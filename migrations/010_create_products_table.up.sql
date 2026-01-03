CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price INTEGER NOT NULL DEFAULT 0,
    image_path VARCHAR(255),
    icon_type VARCHAR(50),
    image_color_1 VARCHAR(50),
    image_color_2 VARCHAR(50),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Seed initial data (optional but good for testing)
INSERT INTO products (code, name, description, price, icon_type, image_color_1, image_color_2) VALUES
('coin_001', 'เหรียญมงคลมหาลาภ', 'เหรียญทองเหลืองแท้ ผ่านพิธีปลุกเสกเพื่อเสริมโชคลาภและการเงิน', 1, 'coin', '#FFD700', '#FDB931'),
('bracelet_001', 'กำไลหินมงคล', 'หินธรรมชาติคัดเกรด เสริมบารมีและช่วยเรื่องสุขภาพ', 1, 'bracelet', '#4a90e2', '#357abd')
ON CONFLICT (code) DO NOTHING;
