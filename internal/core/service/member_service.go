package service

import (
	"errors"
	"fmt"
	"numberniceic/internal/core/domain"
	"numberniceic/internal/core/ports"
)

type MemberService struct {
	repo ports.MemberRepository
}

func NewMemberService(repo ports.MemberRepository) *MemberService {
	return &MemberService{repo: repo}
}

func (s *MemberService) Register(username, password, email, tel string) error {
	// 1. Check if username already exists
	existingMember, err := s.repo.GetByUsername(username)
	if err != nil {
		return fmt.Errorf("error checking existing user: %w", err)
	}
	if existingMember != nil {
		return errors.New("username already exists")
	}

	// 2. Hash the password (Note: Repository Create method already hashes password,
	// but let's keep it consistent with previous logic or adjust repo.
	// Looking at PostgresMemberRepository.Create, it hashes the password again!
	// We should pass the raw password to Create if repo hashes it, OR hash it here and pass hashed.
	// Let's check PostgresMemberRepository again. It does hash it.
	// So we should pass the raw password to Create.

	// Wait, if I pass raw password to Create, and Create hashes it, that's fine.
	// But here I was hashing it too. Let's remove hashing here and let repo handle it
	// OR remove hashing from repo and handle it here.
	// Usually service handles business logic (hashing).
	// Let's check PostgresMemberRepository.Create again.

	/*
		func (r *PostgresMemberRepository) Create(member *domain.Member) error {
			hashedPassword, err := bcrypt.GenerateFromPassword([]byte(member.Password), bcrypt.DefaultCost)
			// ...
		}
	*/

	// Okay, the repo hashes it. So I should NOT hash it here in service if I want to avoid double hashing.
	// However, to be clean, I will just pass the raw password to repo.Create.

	newMember := &domain.Member{
		Username: username,
		Password: password, // Pass raw password, repo will hash it
		Email:    email,
		Tel:      tel,
		Status:   1, // Active by default
	}

	return s.repo.Create(newMember)
}

func (s *MemberService) Login(username, password string) (*domain.Member, error) {
	// 1. Find the user
	member, err := s.repo.GetByUsername(username)
	if err != nil {
		return nil, fmt.Errorf("error finding user: %w", err)
	}
	if member == nil {
		return nil, errors.New("invalid username or password")
	}

	// 2. Compare passwords
	// Use the repo's CheckPassword method if available, or do it here.
	// The repo has CheckPassword method.
	err = s.repo.CheckPassword(member.Password, password)
	if err != nil {
		return nil, errors.New("invalid username or password")
	}

	return member, nil
}

func (s *MemberService) GetMemberByID(id int) (*domain.Member, error) {
	return s.repo.GetByID(id)
}
