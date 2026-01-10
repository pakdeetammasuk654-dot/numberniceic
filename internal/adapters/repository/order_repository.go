package repository

import (
	"database/sql"
	"fmt"
	"numberniceic/internal/core/domain"
	"numberniceic/internal/core/ports"
	"time"
)

type PostgresOrderRepository struct {
	db *sql.DB
}

func NewPostgresOrderRepository(db *sql.DB) ports.OrderRepository {
	return &PostgresOrderRepository{db: db}
}

func (r *PostgresOrderRepository) Create(order *domain.Order) error {
	query := `
		INSERT INTO orders (ref_no, user_id, amount, status, product_name, slip_url, promo_code_id, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
		RETURNING id
	`
	order.CreatedAt = time.Now()
	order.UpdatedAt = time.Now()

	err := r.db.QueryRow(query,
		order.RefNo,
		order.UserID,
		order.Amount,
		order.Status,
		order.ProductName,
		order.SlipURL,
		order.PromoCodeID,
		order.CreatedAt,
		order.UpdatedAt,
	).Scan(&order.ID)

	return err
}

func (r *PostgresOrderRepository) GetByRefNo(refNo string) (*domain.Order, error) {
	query := `
		SELECT o.id, o.ref_no, o.user_id, o.amount, o.status, o.product_name, o.slip_url, o.promo_code_id, o.created_at, o.updated_at, p.image_path
		FROM orders o
		LEFT JOIN products p ON TRIM(o.product_name) = TRIM(p.name)
		WHERE o.ref_no = $1
	`

	var o domain.Order
	var productName, slipURL, productImage sql.NullString

	err := r.db.QueryRow(query, refNo).Scan(
		&o.ID,
		&o.RefNo,
		&o.UserID,
		&o.Amount,
		&o.Status,
		&productName,
		&slipURL,
		&o.PromoCodeID,
		&o.CreatedAt,
		&o.UpdatedAt,
		&productImage,
	)

	if err != nil {
		return nil, err
	}

	o.ProductName = productName.String
	o.SlipURL = slipURL.String
	o.ProductImage = productImage.String

	return &o, nil
}

func (r *PostgresOrderRepository) UpdateStatus(refNo string, status string) error {
	query := `
		UPDATE orders
		SET status = $1, updated_at = $2
		WHERE ref_no = $3
	`
	_, err := r.db.Exec(query, status, time.Now(), refNo)
	return err
}

func (r *PostgresOrderRepository) GetByUserID(userID int) ([]domain.Order, error) {
	// Try to match by name, use TRIM to be safe from whitespaces
	query := `
		SELECT o.id, o.ref_no, o.user_id, o.amount, o.status, o.product_name, o.slip_url, o.promo_code_id, o.created_at, o.updated_at, p.image_path
		FROM orders o
		LEFT JOIN products p ON TRIM(o.product_name) ILIKE TRIM(p.name)
		WHERE o.user_id = $1
		ORDER BY o.created_at DESC
	`

	rows, err := r.db.Query(query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var orders []domain.Order
	for rows.Next() {
		var o domain.Order
		var productName, slipURL, productImage sql.NullString

		err := rows.Scan(
			&o.ID,
			&o.RefNo,
			&o.UserID,
			&o.Amount,
			&o.Status,
			&productName,
			&slipURL,
			&o.PromoCodeID,
			&o.CreatedAt,
			&o.UpdatedAt,
			&productImage,
		)
		if err != nil {
			return nil, err
		}

		o.ProductName = productName.String
		o.SlipURL = slipURL.String
		o.ProductImage = productImage.String

		fmt.Printf("DEBUG: Order ID %d - ProductName: [%s] - Scanned Image: [%s]\n", o.ID, o.ProductName, o.ProductImage)

		orders = append(orders, o)
	}
	return orders, nil
}

func (r *PostgresOrderRepository) UpdateRefNo(id uint, newRefNo string) error {
	query := `
		UPDATE orders
		SET ref_no = $1, updated_at = $2
		WHERE id = $3
	`
	_, err := r.db.Exec(query, newRefNo, time.Now(), id)
	return err
}

func (r *PostgresOrderRepository) UpdatePromoCodeID(refNo string, codeID int) error {
	query := `
		UPDATE orders
		SET promo_code_id = $1, updated_at = $2
		WHERE ref_no = $3
	`
	_, err := r.db.Exec(query, codeID, time.Now(), refNo)
	return err
}

func (r *PostgresOrderRepository) GetAll() ([]domain.Order, error) {
	query := `
		SELECT id, ref_no, user_id, amount, status, product_name, slip_url, promo_code_id, created_at, updated_at
		FROM orders
		ORDER BY created_at DESC
	`

	rows, err := r.db.Query(query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var orders []domain.Order
	for rows.Next() {
		var o domain.Order
		var productName, slipURL sql.NullString // Handle nullable strings

		err := rows.Scan(
			&o.ID,
			&o.RefNo,
			&o.UserID,
			&o.Amount,
			&o.Status,
			&productName,
			&slipURL,
			&o.PromoCodeID,
			&o.CreatedAt,
			&o.UpdatedAt,
		)
		if err != nil {
			return nil, err
		}

		// Assign values if valid, otherwise they default to ""
		o.ProductName = productName.String
		o.SlipURL = slipURL.String

		orders = append(orders, o)
	}
	return orders, nil
}

func (r *PostgresOrderRepository) GetWithPagination(limit, offset int, search string) ([]domain.Order, int64, error) {
	query := `
		SELECT o.id, o.ref_no, o.user_id, o.amount, o.status, o.product_name, o.slip_url, o.promo_code_id, o.created_at, o.updated_at, m.username
		FROM orders o
		LEFT JOIN member m ON o.user_id = m.id
	`
	countQuery := `
		SELECT COUNT(*) 
		FROM orders o
		LEFT JOIN member m ON o.user_id = m.id
	`

	args := []interface{}{}
	whereClause := ""

	if search != "" {
		isNumeric := true
		for _, c := range search {
			if c < '0' || c > '9' {
				isNumeric = false
				break
			}
		}

		if isNumeric {
			whereClause = " WHERE o.id::text LIKE $1 OR o.user_id::text LIKE $1 OR o.ref_no ILIKE $1"
		} else {
			whereClause = " WHERE o.ref_no ILIKE $1 OR o.product_name ILIKE $1 OR m.username ILIKE $1"
		}
		args = append(args, "%"+search+"%")
	}

	query += whereClause
	countQuery += whereClause

	limitIdx := len(args) + 1
	offsetIdx := len(args) + 2

	query += fmt.Sprintf(" ORDER BY o.created_at DESC LIMIT $%d OFFSET $%d", limitIdx, offsetIdx)

	var total int64
	if err := r.db.QueryRow(countQuery, args...).Scan(&total); err != nil {
		return nil, 0, err
	}

	queryArgs := append(args, limit, offset)

	rows, err := r.db.Query(query, queryArgs...)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var orders []domain.Order
	for rows.Next() {
		var o domain.Order
		var productName, slipURL, username sql.NullString

		err := rows.Scan(
			&o.ID,
			&o.RefNo,
			&o.UserID,
			&o.Amount,
			&o.Status,
			&productName,
			&slipURL,
			&o.PromoCodeID,
			&o.CreatedAt,
			&o.UpdatedAt,
			&username,
		)
		if err != nil {
			return nil, 0, err
		}

		o.ProductName = productName.String
		o.SlipURL = slipURL.String
		if username.Valid {
			u := username.String
			o.Username = &u
		}

		orders = append(orders, o)
	}
	return orders, total, nil
}

func (r *PostgresOrderRepository) Delete(id int) error {
	query := `DELETE FROM orders WHERE id = $1`
	_, err := r.db.Exec(query, id)
	return err
}
