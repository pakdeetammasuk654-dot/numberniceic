package repository

import (
	"database/sql"
	"numberniceic/internal/core/domain"
	"numberniceic/internal/core/ports"
	"time"
)

type PostgresShippingAddressRepository struct {
	db *sql.DB
}

func NewPostgresShippingAddressRepository(db *sql.DB) ports.ShippingAddressRepository {
	return &PostgresShippingAddressRepository{db: db}
}

func (r *PostgresShippingAddressRepository) Create(address *domain.ShippingAddress) error {
	query := `
		INSERT INTO shipping_addresses (user_id, recipient_name, phone_number, address_line1, sub_district, district, province, postal_code, is_default, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
		RETURNING id
	`
	address.CreatedAt = time.Now()
	address.UpdatedAt = time.Now()

	return r.db.QueryRow(query,
		address.UserID,
		address.RecipientName,
		address.PhoneNumber,
		address.AddressLine1,
		address.SubDistrict,
		address.District,
		address.Province,
		address.PostalCode,
		address.IsDefault,
		address.CreatedAt,
		address.UpdatedAt,
	).Scan(&address.ID)
}

func (r *PostgresShippingAddressRepository) GetByUserID(userID int) ([]domain.ShippingAddress, error) {
	query := `
		SELECT id, user_id, recipient_name, phone_number, address_line1, sub_district, district, province, postal_code, is_default, created_at, updated_at
		FROM shipping_addresses
		WHERE user_id = $1
		ORDER BY is_default DESC, created_at DESC
	`
	rows, err := r.db.Query(query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var addresses []domain.ShippingAddress
	for rows.Next() {
		var a domain.ShippingAddress
		err := rows.Scan(
			&a.ID,
			&a.UserID,
			&a.RecipientName,
			&a.PhoneNumber,
			&a.AddressLine1,
			&a.SubDistrict,
			&a.District,
			&a.Province,
			&a.PostalCode,
			&a.IsDefault,
			&a.CreatedAt,
			&a.UpdatedAt,
		)
		if err != nil {
			return nil, err
		}
		addresses = append(addresses, a)
	}
	return addresses, nil
}

func (r *PostgresShippingAddressRepository) GetDefaultByUserID(userID int) (*domain.ShippingAddress, error) {
	query := `
		SELECT id, user_id, recipient_name, phone_number, address_line1, sub_district, district, province, postal_code, is_default, created_at, updated_at
		FROM shipping_addresses
		WHERE user_id = $1 AND is_default = TRUE
		LIMIT 1
	`
	var a domain.ShippingAddress
	err := r.db.QueryRow(query, userID).Scan(
		&a.ID,
		&a.UserID,
		&a.RecipientName,
		&a.PhoneNumber,
		&a.AddressLine1,
		&a.SubDistrict,
		&a.District,
		&a.Province,
		&a.PostalCode,
		&a.IsDefault,
		&a.CreatedAt,
		&a.UpdatedAt,
	)
	if err != nil {
		if err == sql.ErrNoRows {
			// If no default, try fetch the latest one
			return r.GetLatestByUserID(userID)
		}
		return nil, err
	}
	return &a, nil
}

func (r *PostgresShippingAddressRepository) GetLatestByUserID(userID int) (*domain.ShippingAddress, error) {
	query := `
		SELECT id, user_id, recipient_name, phone_number, address_line1, sub_district, district, province, postal_code, is_default, created_at, updated_at
		FROM shipping_addresses
		WHERE user_id = $1
		ORDER BY created_at DESC
		LIMIT 1
	`
	var a domain.ShippingAddress
	err := r.db.QueryRow(query, userID).Scan(
		&a.ID,
		&a.UserID,
		&a.RecipientName,
		&a.PhoneNumber,
		&a.AddressLine1,
		&a.SubDistrict,
		&a.District,
		&a.Province,
		&a.PostalCode,
		&a.IsDefault,
		&a.CreatedAt,
		&a.UpdatedAt,
	)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, nil
		}
		return nil, err
	}
	return &a, nil
}

func (r *PostgresShippingAddressRepository) Update(address *domain.ShippingAddress) error {
	query := `
		UPDATE shipping_addresses
		SET recipient_name = $1, phone_number = $2, address_line1 = $3, sub_district = $4, district = $5, province = $6, postal_code = $7, is_default = $8, updated_at = $9
		WHERE id = $10
	`
	address.UpdatedAt = time.Now()
	_, err := r.db.Exec(query,
		address.RecipientName,
		address.PhoneNumber,
		address.AddressLine1,
		address.SubDistrict,
		address.District,
		address.Province,
		address.PostalCode,
		address.IsDefault,
		address.UpdatedAt,
		address.ID,
	)
	return err
}

func (r *PostgresShippingAddressRepository) Delete(id int) error {
	query := `DELETE FROM shipping_addresses WHERE id = $1`
	_, err := r.db.Exec(query, id)
	return err
}
