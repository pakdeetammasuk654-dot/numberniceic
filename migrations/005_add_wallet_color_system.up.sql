-- Add day_of_birth to member table (singular 'member')
ALTER TABLE member ADD COLUMN IF NOT EXISTS day_of_birth INT;

-- Create wallet_colors table
CREATE TABLE IF NOT EXISTS wallet_colors (
    id SERIAL PRIMARY KEY,
    day_of_week INT NOT NULL UNIQUE, -- 0=Sunday, 1=Monday, ..., 6=Saturday
    color_name VARCHAR(100) NOT NULL,
    color_hex VARCHAR(7) NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Pre-populate with default values
INSERT INTO wallet_colors (day_of_week, color_name, color_hex, description) VALUES
(0, 'สีแดง', '#FF0000', 'เสริมด้านอำนาจ บารมี และความเป็นผู้นำ'),
(1, 'สีขาว, ครีม, เหลือง', '#FFFF00', 'เสริมด้านการเงิน โชคลาภ และความเมตตา'),
(2, 'สีชมพู, ม่วง', '#FFC0CB', 'เสริมด้านเสน่ห์ คนอุปถัมภ์ และความช่วยเหลือ'),
(3, 'สีเขียว', '#008000', 'เสริมด้านสุขภาพ และความขยันหมั่นเพียร'),
(4, 'สีส้ม, แสด', '#FFA500', 'เสริมด้านสติปัญญา และความสำเร็จในหน้าที่การงาน'),
(5, 'สีฟ้า, น้ำเงิน', '#0000FF', 'เสริมด้านความสุข และความเจริญรุ่งเรือง'),
(6, 'สีดำ, เทา, น้ำตาลเข้ม', '#000000', 'เสริมด้านความมั่นคง และการปกป้องคุ้มครอง')
ON CONFLICT (day_of_week) DO NOTHING;
