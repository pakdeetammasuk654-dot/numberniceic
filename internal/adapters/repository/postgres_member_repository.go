package repository

import (
	"database/sql"
	"errors"
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
	// Use 'status' but skip timestamps for now
	query := `
		INSERT INTO member (username, email, tel, status, provider, provider_id, avatar_url)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
		RETURNING id
	`
	// Default status to 1 (Normal User) if not specified
	status := 1
	if member.Status != 0 {
		status = member.Status
	}

	err := r.db.QueryRow(query, member.Username, member.Email, member.Tel, status, member.Provider, member.ProviderID, member.AvatarURL).Scan(&member.ID)
	if err != nil {
		return err
	}
	return nil
}

func (r *PostgresMemberRepository) GetByEmail(email string) (*domain.Member, error) {
	if email == "" {
		return nil, nil
	}
	query := `
		SELECT id, username, email, tel, status, day_of_birth, COALESCE(assigned_colors, ''), COALESCE(provider, ''), COALESCE(provider_id, ''), COALESCE(avatar_url, ''), vip_expires_at
		FROM member
		WHERE email = $1
	`
	var m domain.Member
	var provider, providerID, avatarURL sql.NullString
	err := r.db.QueryRow(query, email).Scan(&m.ID, &m.Username, &m.Email, &m.Tel, &m.Status, &m.DayOfBirth, &m.AssignedColors, &provider, &providerID, &avatarURL, &m.VIPExpiresAt)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, nil
		}
		return nil, err
	}
	m.Provider = provider.String
	m.ProviderID = providerID.String
	m.AvatarURL = avatarURL.String
	m.Username = strings.TrimSpace(m.Username)
	m.Email = strings.TrimSpace(m.Email)
	m.Tel = strings.TrimSpace(m.Tel)
	return &m, nil
}

func (r *PostgresMemberRepository) GetByUsername(username string) (*domain.Member, error) {
	// Use 'status' but skip timestamps for now
	query := `
		SELECT id, username, email, tel, status, day_of_birth, COALESCE(assigned_colors, ''), COALESCE(provider, ''), COALESCE(provider_id, ''), COALESCE(avatar_url, ''), vip_expires_at
		FROM member
		WHERE username = $1
	`
	var m domain.Member
	var provider, providerID, avatarURL sql.NullString
	err := r.db.QueryRow(query, username).Scan(&m.ID, &m.Username, &m.Email, &m.Tel, &m.Status, &m.DayOfBirth, &m.AssignedColors, &provider, &providerID, &avatarURL, &m.VIPExpiresAt)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, nil
		}
		return nil, err
	}
	m.Provider = provider.String
	m.ProviderID = providerID.String
	m.AvatarURL = avatarURL.String
	m.Username = strings.TrimSpace(m.Username)
	m.Email = strings.TrimSpace(m.Email)
	m.Tel = strings.TrimSpace(m.Tel)
	return &m, nil
}

func (r *PostgresMemberRepository) GetByID(id int) (*domain.Member, error) {
	// Use 'status' but skip timestamps for now
	query := `
		SELECT id, username, email, tel, status, day_of_birth, COALESCE(assigned_colors, ''), COALESCE(provider, ''), COALESCE(provider_id, ''), COALESCE(avatar_url, ''), vip_expires_at
		FROM member
		WHERE id = $1
	`
	var m domain.Member
	var provider, providerID, avatarURL sql.NullString
	err := r.db.QueryRow(query, id).Scan(&m.ID, &m.Username, &m.Email, &m.Tel, &m.Status, &m.DayOfBirth, &m.AssignedColors, &provider, &providerID, &avatarURL, &m.VIPExpiresAt)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, nil
		}
		return nil, err
	}
	m.Provider = provider.String
	m.ProviderID = providerID.String
	m.AvatarURL = avatarURL.String
	m.Username = strings.TrimSpace(m.Username)
	m.Email = strings.TrimSpace(m.Email)
	m.Tel = strings.TrimSpace(m.Tel)
	return &m, nil
}

func (r *PostgresMemberRepository) GetByProvider(provider, providerID string) (*domain.Member, error) {
	query := `
		SELECT id, username, email, tel, status, day_of_birth, COALESCE(assigned_colors, ''), COALESCE(provider, ''), COALESCE(provider_id, ''), COALESCE(avatar_url, '')
		FROM member
		WHERE provider = $1 AND provider_id = $2
	`
	var m domain.Member
	var p, pID, aURL sql.NullString
	err := r.db.QueryRow(query, provider, providerID).Scan(&m.ID, &m.Username, &m.Email, &m.Tel, &m.Status, &m.DayOfBirth, &m.AssignedColors, &p, &pID, &aURL)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, nil
		}
		return nil, err
	}
	m.Provider = p.String
	m.ProviderID = pID.String
	m.AvatarURL = aURL.String
	m.Username = strings.TrimSpace(m.Username)
	m.Email = strings.TrimSpace(m.Email)
	m.Tel = strings.TrimSpace(m.Tel)
	return &m, nil
}

func (r *PostgresMemberRepository) Update(member *domain.Member) error {
	query := `
		UPDATE member 
		SET username = $1, email = $2, tel = $3, avatar_url = $4, provider = $5, provider_id = $6
		WHERE id = $7
	`
	_, err := r.db.Exec(query, member.Username, member.Email, member.Tel, member.AvatarURL, member.Provider, member.ProviderID, member.ID)
	return err
}

func (r *PostgresMemberRepository) Delete(id int) error {
	query := `DELETE FROM member WHERE id = $1`
	_, err := r.db.Exec(query, id)
	return err
}

// GetAllMembers retrieves all members (for admin)
func (r *PostgresMemberRepository) GetAllMembers() ([]domain.Member, error) {
	// Use 'status' but skip timestamps for now
	// ORDER BY id DESC (Latest first)
	query := `
		SELECT id, username, email, tel, status, day_of_birth, COALESCE(assigned_colors, '')
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
		err := rows.Scan(&m.ID, &m.Username, &m.Email, &m.Tel, &m.Status, &m.DayOfBirth, &m.AssignedColors)
		if err != nil {
			return nil, err
		}
		m.Username = strings.TrimSpace(m.Username)
		m.Email = strings.TrimSpace(m.Email)
		m.Tel = strings.TrimSpace(m.Tel)
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

	query := `UPDATE member SET status = $1 WHERE id = $2 AND status < 9`
	_, err := r.db.Exec(query, newStatus, id)
	return err
}

func (r *PostgresMemberRepository) SetVIPWithExpiry(id int, duration string) error {
	// duration should be like '365 days'
	query := fmt.Sprintf(`UPDATE member SET status = 2, vip_expires_at = NOW() + INTERVAL '%s' WHERE id = $1 AND status < 9`, duration)
	_, err := r.db.Exec(query, id)
	return err
}

func (r *PostgresMemberRepository) UpdateDayOfBirth(id int, dayOfWeek int) error {
	query := `UPDATE member SET day_of_birth = $1 WHERE id = $2`
	_, err := r.db.Exec(query, dayOfWeek, id)
	return err
}

func (r *PostgresMemberRepository) UpdateAssignedColors(id int, colors string) error {
	query := `UPDATE member SET assigned_colors = $1 WHERE id = $2`
	_, err := r.db.Exec(query, colors, id)
	return err
}

func (r *PostgresMemberRepository) GetMembersWithAssignedColors() ([]domain.Member, error) {
	query := `
		SELECT id, username, email, tel, status, day_of_birth, assigned_colors
		FROM member
		WHERE assigned_colors IS NOT NULL AND assigned_colors != ''
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
		err := rows.Scan(&m.ID, &m.Username, &m.Email, &m.Tel, &m.Status, &m.DayOfBirth, &m.AssignedColors)
		if err != nil {
			return nil, err
		}
		m.Username = strings.TrimSpace(m.Username)
		m.Email = strings.TrimSpace(m.Email)
		m.Tel = strings.TrimSpace(m.Tel)
		members = append(members, m)
	}
	return members, nil
}

func (r *PostgresMemberRepository) CreateNotification(userID int, title, message string) error {
	query := `INSERT INTO user_notifications (user_id, title, message, created_at) VALUES ($1, $2, $3, NOW())`
	_, err := r.db.Exec(query, userID, title, message)
	return err
}

func (r *PostgresMemberRepository) CreateBroadcastNotification(title, message string) error {
	// 1. Get all active member IDs
	rows, err := r.db.Query("SELECT id FROM member WHERE status >= 0")
	if err != nil {
		return err
	}
	defer rows.Close()

	var ids []int
	for rows.Next() {
		var id int
		if err := rows.Scan(&id); err != nil {
			continue
		}
		ids = append(ids, id)
	}

	// 2. Iterate and insert individually to ignore FK errors
	for _, id := range ids {
		// Use CreateNotification and ignore error
		// We could log error here but let's keep it simple
		_ = r.CreateNotification(id, title, message)
	}

	return nil
}

func (r *PostgresMemberRepository) SaveFCMToken(userID int, token, platform string) error {
	query := `
		INSERT INTO fcm_tokens (user_id, token, platform, updated_at)
		VALUES ($1, $2, $3, NOW())
		ON CONFLICT (token) DO UPDATE 
		SET user_id = EXCLUDED.user_id, updated_at = NOW();
	`
	_, err := r.db.Exec(query, userID, token, platform)
	return err
}

func (r *PostgresMemberRepository) GetFCMTokens(userID int) ([]string, error) {
	rows, err := r.db.Query("SELECT token FROM fcm_tokens WHERE user_id = $1", userID)
	if err != nil { return nil, err }
	defer rows.Close()
	
	var tokens []string
	for rows.Next() {
		var t string
		if err := rows.Scan(&t); err == nil {
			tokens = append(tokens, t)
		}
	}
	return tokens, nil
}

func (r *PostgresMemberRepository) GetAllFCMTokens() ([]string, error) {
	rows, err := r.db.Query("SELECT token FROM fcm_tokens")
	if err != nil { return nil, err }
	defer rows.Close()
	
	var tokens []string
	for rows.Next() {
		var t string
		if err := rows.Scan(&t); err == nil {
			tokens = append(tokens, t)
		}
	}
	return tokens, nil
}
