package repository

import (
	"database/sql"
	"fmt"
	"numberniceic/internal/core/domain"
	"numberniceic/internal/core/ports"
	"strings"
)

type PostgresMemberRepository struct {
	db *sql.DB
}

func NewPostgresMemberRepository(db *sql.DB) ports.MemberRepository {
	return &PostgresMemberRepository{db: db}
}

func (r *PostgresMemberRepository) Create(member *domain.Member) error {
	query := `
		INSERT INTO public.member (username, password, email, tel, status)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING id
	`
	// Trim spaces from char(n) fields if necessary, though Postgres usually handles varchar better.
	// Since the schema uses char(30), we should be mindful of padding, but for insertion, it's fine.
	err := r.db.QueryRow(query,
		strings.TrimSpace(member.Username),
		member.Password,
		strings.TrimSpace(member.Email),
		strings.TrimSpace(member.Tel),
		member.Status,
	).Scan(&member.ID)

	if err != nil {
		return fmt.Errorf("failed to create member: %w", err)
	}
	return nil
}

func (r *PostgresMemberRepository) FindByUsername(username string) (*domain.Member, error) {
	query := `
		SELECT id, username, password, email, tel, status
		FROM public.member
		WHERE trim(username) = $1
	`
	var member domain.Member
	var email, tel sql.NullString // Handle potential NULLs

	err := r.db.QueryRow(query, strings.TrimSpace(username)).Scan(
		&member.ID,
		&member.Username,
		&member.Password,
		&email,
		&tel,
		&member.Status,
	)

	if err != nil {
		if err == sql.ErrNoRows {
			return nil, nil // Not found
		}
		return nil, fmt.Errorf("failed to find member by username: %w", err)
	}

	// Clean up the retrieved data (remove padding from char types)
	member.Username = strings.TrimSpace(member.Username)
	member.Password = strings.TrimSpace(member.Password)
	if email.Valid {
		member.Email = strings.TrimSpace(email.String)
	}
	if tel.Valid {
		member.Tel = strings.TrimSpace(tel.String)
	}

	return &member, nil
}

func (r *PostgresMemberRepository) FindByID(id int) (*domain.Member, error) {
	query := `
		SELECT id, username, password, email, tel, status
		FROM public.member
		WHERE id = $1
	`
	var member domain.Member
	var email, tel sql.NullString

	err := r.db.QueryRow(query, id).Scan(
		&member.ID,
		&member.Username,
		&member.Password,
		&email,
		&tel,
		&member.Status,
	)

	if err != nil {
		if err == sql.ErrNoRows {
			return nil, nil
		}
		return nil, fmt.Errorf("failed to find member by id: %w", err)
	}

	member.Username = strings.TrimSpace(member.Username)
	member.Password = strings.TrimSpace(member.Password)
	if email.Valid {
		member.Email = strings.TrimSpace(email.String)
	}
	if tel.Valid {
		member.Tel = strings.TrimSpace(tel.String)
	}

	return &member, nil
}
