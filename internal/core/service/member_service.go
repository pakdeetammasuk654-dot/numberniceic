package service

import (
	"errors"
	"fmt"
	"html"
	"log"
	"numberniceic/internal/core/domain"
	"numberniceic/internal/core/ports"
)

type MemberService struct {
	repo     ports.MemberRepository
	firebase *FirebaseService
}

func NewMemberService(repo ports.MemberRepository, fb *FirebaseService) *MemberService {
	return &MemberService{repo: repo, firebase: fb}
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

func (s *MemberService) CreateUserNotification(userID int, title, message string, data map[string]string) error {
	// Save to DB first (DB doesn't store structured data yet, so we just save title/message)
	err := s.repo.CreateNotification(userID, title, message, data)
	if err != nil {
		return err
	}

	// Send Push Notification (Async)
	if s.firebase != nil {
		go func() {
			tokens, err := s.repo.GetFCMTokens(userID)
			log.Printf("DEBUG: Found %d FCM Tokens for UserID: %d", len(tokens), userID)

			if err != nil {
				log.Printf("Error fetching FCM tokens for user %d: %v", userID, err)
				return
			}
			if len(tokens) > 0 {
				err := s.firebase.SendMulticast(tokens, title, message, data)
				if err != nil {
					log.Printf("ERROR sending multicast: %v", err)
				}
			} else {
				log.Printf("DEBUG: No tokens found for UserID %d. Notification saved but not pushed.", userID)
			}
		}()
	}

	return nil
}

func (s *MemberService) CreateBroadcastNotification(title, message string) error {
	return s.CreateBroadcastNotificationWithData(title, message, nil)
}

func (s *MemberService) CreateBroadcastNotificationWithData(title, message string, data map[string]string) error {
	// Save to DB
	err := s.repo.CreateBroadcastNotification(title, message, data)
	if err != nil {
		return err
	}

	// Send to All Devices
	if s.firebase != nil {
		go func() {
			tokens, err := s.repo.GetAllFCMTokens()
			if err == nil && len(tokens) > 0 {
				batchSize := 500
				for i := 0; i < len(tokens); i += batchSize {
					end := i + batchSize
					if end > len(tokens) {
						end = len(tokens)
					}
					batch := tokens[i:end]
					// Pass data parameter to Firebase
					s.firebase.SendMulticast(batch, title, message, data)
				}
			}
		}()
	}

	return nil
}

func (s *MemberService) SendWalletColorNotification(memberID int) error {
	member, err := s.repo.GetByID(memberID)
	if err != nil {
		return err
	}
	if member.AssignedColors == "" || member.AssignedColors == ",,,," {
		return errors.New("ยังไม่ได้กำหนดสีกระเป๋าให้ลูกค้ารายนี้")
	}

	// Check if notification was sent recently (within 5 seconds for testing) to prevent duplicates
	// if member.WalletColorsNotifiedAt != nil {
	// 	timeSinceLastNotification := time.Since(*member.WalletColorsNotifiedAt)
	// 	if timeSinceLastNotification < 5*time.Second {
	// 		log.Printf("⚠️ Duplicate notification prevented for user %d (last sent: %v ago)", memberID, timeSinceLastNotification)
	// 		return errors.New("เพิ่งส่งการแจ้งเตือนไปแล้ว กรุณารอสักครู่")
	// 	}
	// }

	title := "สีกระเป๋ามงคลของคุณมาแล้ว! ✨"

	message := "คุณนินได้ทำการวิเคราะห์สีกระเป๋ามงคลให้คุณเรียบร้อยแล้ว สามารถตรวจสอบรายละเอียดได้ที่หน้าโปรไฟล์ของคุณ"
	log.Printf("DEBUG: SendWalletColorNotification Message: %s", message)

	// CreateUserNotification handles local DB save and Firebase Push
	data := map[string]string{
		"type":   "wallet_colors",
		"colors": member.AssignedColors,
	}
	err = s.CreateUserNotification(member.ID, title, message, data)
	if err != nil {
		return err
	}

	// Update notified timestamp in member table
	return s.repo.UpdateWalletColorsNotifiedAt(member.ID)
}

func (s *MemberService) GetAllMembers() ([]domain.Member, error) {
	return s.repo.GetAllMembers()
}

func (s *MemberService) SaveDeviceToken(userID int, token, platform string) error {
	return s.repo.SaveFCMToken(userID, token, platform)
}
