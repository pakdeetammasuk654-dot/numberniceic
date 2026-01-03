ALTER TABLE promotional_codes ADD COLUMN owner_member_id INT REFERENCES member(id);
ALTER TABLE promotional_codes ADD COLUMN product_name VARCHAR(255);
