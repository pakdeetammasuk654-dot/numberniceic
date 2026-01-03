package repository

import (
	"database/sql"
	"errors"
	"fmt"
	"numberniceic/internal/core/domain"
	"time"
)

type PostgresProductRepository struct {
	db *sql.DB
}

func NewPostgresProductRepository(db *sql.DB) *PostgresProductRepository {
	return &PostgresProductRepository{db: db}
}

func (r *PostgresProductRepository) GetAll() ([]domain.Product, error) {
	query := `SELECT id, code, name, description, price, image_path, icon_type, image_color_1, image_color_2, is_active, created_at, updated_at FROM products ORDER BY created_at DESC`
	rows, err := r.db.Query(query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var products []domain.Product
	for rows.Next() {
		var p domain.Product
		var imagePath, iconType, color1, color2 sql.NullString
		err := rows.Scan(&p.ID, &p.Code, &p.Name, &p.Description, &p.Price, &imagePath, &iconType, &color1, &color2, &p.IsActive, &p.CreatedAt, &p.UpdatedAt)
		if err != nil {
			return nil, err
		}
		p.ImagePath = imagePath.String
		p.IconType = iconType.String
		p.ImageColor1 = color1.String
		p.ImageColor2 = color2.String
		products = append(products, p)
	}
	return products, nil
}

func (r *PostgresProductRepository) GetByID(id int) (*domain.Product, error) {
	query := `SELECT id, code, name, description, price, image_path, icon_type, image_color_1, image_color_2, is_active, created_at, updated_at FROM products WHERE id = $1`
	var p domain.Product
	var imagePath, iconType, color1, color2 sql.NullString
	err := r.db.QueryRow(query, id).Scan(&p.ID, &p.Code, &p.Name, &p.Description, &p.Price, &imagePath, &iconType, &color1, &color2, &p.IsActive, &p.CreatedAt, &p.UpdatedAt)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, errors.New("product not found")
		}
		return nil, err
	}
	p.ImagePath = imagePath.String
	p.IconType = iconType.String
	p.ImageColor1 = color1.String
	p.ImageColor2 = color2.String
	return &p, nil
}

func (r *PostgresProductRepository) GetByCode(code string) (*domain.Product, error) {
	query := `SELECT id, code, name, description, price, image_path, icon_type, image_color_1, image_color_2, is_active, created_at, updated_at FROM products WHERE code = $1`
	var p domain.Product
	var imagePath, iconType, color1, color2 sql.NullString
	err := r.db.QueryRow(query, code).Scan(&p.ID, &p.Code, &p.Name, &p.Description, &p.Price, &imagePath, &iconType, &color1, &color2, &p.IsActive, &p.CreatedAt, &p.UpdatedAt)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, errors.New("product not found")
		}
		return nil, err
	}
	p.ImagePath = imagePath.String
	p.IconType = iconType.String
	p.ImageColor1 = color1.String
	p.ImageColor2 = color2.String
	return &p, nil
}

func (r *PostgresProductRepository) Create(p *domain.Product) error {
	query := `INSERT INTO products (code, name, description, price, image_path, icon_type, image_color_1, image_color_2, is_active) 
	          VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING id`
	err := r.db.QueryRow(query, p.Code, p.Name, p.Description, p.Price,
		newNullString(p.ImagePath), newNullString(p.IconType),
		newNullString(p.ImageColor1), newNullString(p.ImageColor2), p.IsActive).Scan(&p.ID)
	return err
}

func (r *PostgresProductRepository) Update(p *domain.Product) error {
	query := `UPDATE products SET code=$1, name=$2, description=$3, price=$4, image_path=$5, icon_type=$6, image_color_1=$7, image_color_2=$8, is_active=$9, updated_at=$10 WHERE id=$11`
	_, err := r.db.Exec(query, p.Code, p.Name, p.Description, p.Price,
		newNullString(p.ImagePath), newNullString(p.IconType),
		newNullString(p.ImageColor1), newNullString(p.ImageColor2),
		p.IsActive, time.Now(), p.ID)
	return err
}

func (r *PostgresProductRepository) Delete(id int) error {
	query := `DELETE FROM products WHERE id = $1`
	result, err := r.db.Exec(query, id)
	if err != nil {
		return err
	}
	rows, _ := result.RowsAffected()
	if rows == 0 {
		return fmt.Errorf("product not found")
	}
	return nil
}

func newNullString(s string) sql.NullString {
	if s == "" {
		return sql.NullString{Valid: false}
	}
	return sql.NullString{String: s, Valid: true}
}
