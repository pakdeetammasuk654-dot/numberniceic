package service

import (
	"numberniceic/internal/core/domain"
)

type NotificationRepository interface {
	Create(n *domain.UserNotification) error
	GetByUserID(userID int) ([]domain.UserNotification, error)
	MarkAsRead(id int) error
	Delete(id int) error
	CountUnread(userID int) (int, error)
	GetAllForAdmin(limit int) ([]domain.AdminNotificationHistory, error)
}

type NotificationService struct {
	repo NotificationRepository
}

func NewNotificationService(repo NotificationRepository) *NotificationService {
	return &NotificationService{repo: repo}
}

func (s *NotificationService) SendNotification(userID int, title, message string) error {
	notification := &domain.UserNotification{
		UserID:  userID,
		Title:   title,
		Message: message,
	}
	return s.repo.Create(notification)
}

func (s *NotificationService) GetUserNotifications(userID int) ([]domain.UserNotification, error) {
	return s.repo.GetByUserID(userID)
}

func (s *NotificationService) MarkAsRead(id int) error {
	return s.repo.MarkAsRead(id)
}

func (s *NotificationService) Delete(id int) error {
	return s.repo.Delete(id)
}

func (s *NotificationService) GetUnreadCount(userID int) (int, error) {
	return s.repo.CountUnread(userID)
}

func (s *NotificationService) GetNotificationHistory(limit int) ([]domain.AdminNotificationHistory, error) {
	return s.repo.GetAllForAdmin(limit)
}
