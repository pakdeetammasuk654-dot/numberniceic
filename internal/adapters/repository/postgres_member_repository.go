package repository

import (
	"database/sql"
	"errors"
	"numberniceic/internal/core/domain"
	"numberniceic/internal/core/ports"

	"golang.org/x/crypto/bcrypt"
)

type PostgresMemberRepository struct {
	db *sql.DB
}

func NewPostgresMemberRepository(db *sql.DB) ports.MemberRepository {
	return &PostgresMemberRepository{db: db}
}

func (r *PostgresMemberRepository) Create(member *domain.Member) error {
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(member.Password), bcrypt.DefaultCost)
	if err != nil {
		return err
	}

	// Use 'status' but skip timestamps for now
	query := `
		INSERT INTO member (username, password, email, tel, status)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING id
	`
	// Default status to 1 (Normal User) if not specified
	status := 1
	if member.Status != 0 {
		status = member.Status
	}

	err = r.db.QueryRow(query, member.Username, string(hashedPassword), member.Email, member.Tel, status).Scan(&member.ID)
	if err != nil {
		return err
	}
	member.Password = "" // Don't return password
	return nil
}

func (r *PostgresMemberRepository) GetByEmail(email string) (*domain.Member, error) {
	if email == "" {
		return nil, nil
	}
	query := `
		SELECT id, username, password, email, tel, status
		FROM member
		WHERE email = $1
	`
	var m domain.Member
	err := r.db.QueryRow(query, email).Scan(&m.ID, &m.Username, &m.Password, &m.Email, &m.Tel, &m.Status)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, nil
		}
		return nil, err
	}
	return &m, nil
}

func (r *PostgresMemberRepository) GetByUsername(username string) (*domain.Member, error) {
	// Use 'status' but skip timestamps for now
	query := `
		SELECT id, username, password, email, tel, status
		FROM member
		WHERE username = $1
	`
	var m domain.Member
	err := r.db.QueryRow(query, username).Scan(&m.ID, &m.Username, &m.Password, &m.Email, &m.Tel, &m.Status)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, nil
		}
		return nil, err
	}
	return &m, nil
}

func (r *PostgresMemberRepository) GetByID(id int) (*domain.Member, error) {
	// Use 'status' but skip timestamps for now
	query := `
		SELECT id, username, password, email, tel, status
		FROM member
		WHERE id = $1
	`
	var m domain.Member
	err := r.db.QueryRow(query, id).Scan(&m.ID, &m.Username, &m.Password, &m.Email, &m.Tel, &m.Status)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, nil
		}
		return nil, err
	}
	return &m, nil
}

func (r *PostgresMemberRepository) Update(member *domain.Member) error {
	// Implement update logic if needed
	return nil
}

func (r *PostgresMemberRepository) Delete(id int) error {
	query := `DELETE FROM member WHERE id = $1`
	_, err := r.db.Exec(query, id)
	return err
}

func (r *PostgresMemberRepository) CheckPassword(hashedPassword, password string) error {
	return bcrypt.CompareHashAndPassword([]byte(hashedPassword), []byte(password))
}

// GetAllMembers retrieves all members (for admin)
func (r *PostgresMemberRepository) GetAllMembers() ([]domain.Member, error) {
	// Use 'status' but skip timestamps for now
	// ORDER BY id DESC (Latest first)
	query := `
		SELECT id, username, email, tel, status
		FROM member
		ORDER BY id DESC
	`
	rows, err := r.db.Query(query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var members []domain.Member
	for rows.Next() {
		var m domain.Member
		err := rows.Scan(&m.ID, &m.Username, &m.Email, &m.Tel, &m.Status)
		if err != nil {
			return nil, err
		}
		members = append(members, m)
	}
	return members, nil
}

// UpdateStatus updates the status of a member (for admin)
func (r *PostgresMemberRepository) UpdateStatus(id int, status int) error {
	query := `UPDATE member SET status = $1 WHERE id = $2`
	result, err := r.db.Exec(query, status, id)
	if err != nil {
		return err
	}
	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if rowsAffected == 0 {
		return errors.New("member not found")
	}
	return nil
}

// SetVIP updates the VIP status of a member
// For now, we assumed Status 2 represents VIP, or we need to add is_vip column.
// As a safe bet without altering schema yet, let's assume Status 2 is VIP.
// If Status was 1 (Normal), it becomes 2. If it was 9 (Admin), it stays 9?
// Let's implement it as: Update status to 2 if it's currently 1.
func (r *PostgresMemberRepository) SetVIP(id int, isVIP bool) error {
	var newStatus int
	if isVIP {
		newStatus = 2 // VIP
	} else {
		newStatus = 1 // Normal
	}

	// Ensure we don't downgrade Admin (9) accidentally, so we should check current status first or use conditional update
	// But simplest is just setting it for now as requested.
	// Or better: UPDATE member SET status = 2 WHERE id = $1 AND status < 9
	query := `UPDATE member SET status = $1 WHERE id = $2 AND status < 9`
	_, err := r.db.Exec(query, newStatus, id)
	return err
}
