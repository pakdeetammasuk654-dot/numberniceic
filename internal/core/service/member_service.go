package service

import (
	"errors"
	"fmt"
	"numberniceic/internal/core/domain"
	"numberniceic/internal/core/ports"

	"golang.org/x/crypto/bcrypt"
)

type MemberService struct {
	repo ports.MemberRepository
}

func NewMemberService(repo ports.MemberRepository) *MemberService {
	return &MemberService{repo: repo}
}

func (s *MemberService) Register(username, password, email, tel string) error {
	// 1. Check if username already exists
	existingMember, err := s.repo.FindByUsername(username)
	if err != nil {
		return fmt.Errorf("error checking existing user: %w", err)
	}
	if existingMember != nil {
		return errors.New("username already exists")
	}

	// 2. Hash the password
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return fmt.Errorf("failed to hash password: %w", err)
	}

	// 3. Create the member
	newMember := &domain.Member{
		Username: username,
		Password: string(hashedPassword),
		Email:    email,
		Tel:      tel,
		Status:   1, // Active by default
	}

	return s.repo.Create(newMember)
}

func (s *MemberService) Login(username, password string) (*domain.Member, error) {
	// 1. Find the user
	member, err := s.repo.FindByUsername(username)
	if err != nil {
		return nil, fmt.Errorf("error finding user: %w", err)
	}
	if member == nil {
		return nil, errors.New("invalid username or password")
	}

	// 2. Compare passwords
	err = bcrypt.CompareHashAndPassword([]byte(member.Password), []byte(password))
	if err != nil {
		return nil, errors.New("invalid username or password")
	}

	return member, nil
}

func (s *MemberService) GetMemberByID(id int) (*domain.Member, error) {
	return s.repo.FindByID(id)
}
