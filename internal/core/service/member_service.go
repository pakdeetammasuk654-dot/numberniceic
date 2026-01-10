package service

import (
	"errors"
	"fmt"
	"html"
	"numberniceic/internal/core/domain"
	"numberniceic/internal/core/ports"
)

type MemberService struct {
	repo ports.MemberRepository
}

func NewMemberService(repo ports.MemberRepository) *MemberService {
	return &MemberService{repo: repo}
}

func (s *MemberService) GetMemberByID(id int) (*domain.Member, error) {
	return s.repo.GetByID(id)
}

func (s *MemberService) UpdateDayOfBirth(id int, dayOfWeek int) error {
	if dayOfWeek < 0 || dayOfWeek > 6 {
		return errors.New("invalid day of week")
	}
	return s.repo.UpdateDayOfBirth(id, dayOfWeek)
}

func (s *MemberService) HandleSocialLogin(provider, providerID, email, name, avatarURL string) (*domain.Member, error) {
	// 1. Check if user exists by Provider + ID
	member, err := s.repo.GetByProvider(provider, providerID)
	if err != nil {
		return nil, fmt.Errorf("error checking provider: %w", err)
	}
	if member != nil {
		// Update Avatar if changed
		if avatarURL != "" && member.AvatarURL != avatarURL {
			member.AvatarURL = avatarURL
			// We can ignore error here as it's not critical
			_ = s.repo.Update(member)
		}
		return member, nil
	}

	// 2. Check if email exists (Link account)
	if email != "" {
		member, err = s.repo.GetByEmail(email)
		if err != nil {
			return nil, fmt.Errorf("error checking email: %w", err)
		}
		if member != nil {
			// Found by email -> Update provider info to link account to the latest provider used
			member.Provider = provider
			member.ProviderID = providerID
			if avatarURL != "" {
				member.AvatarURL = avatarURL
			}
			// Update the record in database
			_ = s.repo.Update(member)
			return member, nil
		}
	}

	// 3. Create new user
	// Generate unique username
	username := name
	if username == "" {
		// Use shorter unique suffix (first 6 chars of providerID to avoid long ugly names)
		shortID := providerID
		if len(providerID) > 6 {
			shortID = providerID[:6]
		}
		username = fmt.Sprintf("%s_user_%s", provider, shortID)
	}

	// Ensure username is unique
	baseUsername := username
	counter := 1
	for {
		exists, _ := s.repo.GetByUsername(username)
		if exists == nil {
			break
		}
		// If collision, append counter
		username = fmt.Sprintf("%s_%d", baseUsername, counter)
		counter++
	}

	newMember := &domain.Member{
		Username:   username,
		Email:      email,
		Provider:   provider,
		ProviderID: providerID,
		AvatarURL:  avatarURL,
		Status:     1,
	}

	err = s.repo.Create(newMember)
	if err != nil {
		return nil, err
	}
	return newMember, nil
}

func (s *MemberService) UpdateProfile(id int, username, email, tel string) error {
	// Check if username is taken (if changed)
	if username != "" {
		existing, err := s.repo.GetByUsername(username)
		if err == nil && existing != nil && existing.ID != id {
			return errors.New("ชื่อผู้ใช้นี้มีผู้ใช้งานแล้ว")
		}
	}

	// For simplicity, we assume repo has a generic Update method or we create a specific one.
	// Since MemberRepository interface has Update(member *domain.Member), let's use that.
	member, err := s.repo.GetByID(id)
	if err != nil {
		return err
	}

	if username != "" {
		member.Username = html.EscapeString(username)
	}
	if email != "" {
		member.Email = html.EscapeString(email)
	}
	if tel != "" {
		member.Tel = html.EscapeString(tel)
	}

	return s.repo.Update(member)
}

func (s *MemberService) CreateUserNotification(userID int, title, message string) error {
	return s.repo.CreateNotification(userID, title, message)
}

func (s *MemberService) CreateBroadcastNotification(title, message string) error {
	return s.repo.CreateBroadcastNotification(title, message)
}
