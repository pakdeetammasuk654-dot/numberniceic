package service

import (
	"numberniceic/internal/core/domain"
	"numberniceic/internal/core/ports"
	"time"
)

var defaultBuddhistMessages = []string{
	"ธรรมะสวัสดี วันพระนี้ขอให้มีแต่ความสุขกาย สบายใจ",
	"วันนี้วันพระ ขอพระคุ้มครอง วิถีแห่งบุญนำพาความสุขมาให้",
	"สะสมบุญวันละนิด จิตใจผ่องใส ขอให้เป็นวันพระที่เปี่ยมด้วยสติ",
	"แสงเทียนสว่างที่กลางใจ ขอให้บุญรักษาในวันพระนี้",
	"วันนี้วันพระ ตั้งจิตให้มั่น ทำดีให้ถึงพร้อมเพื่อความสงบสุข",
	"บุญระลึก กุศลนำพา ขอให้วันพระนี้เป็นวันที่ดีสำหรับคุณ",
	"ธรรมะคือทางสว่าง ขอให้ทุกท่านมีความสุขสงบในวันมงคลนี้",
	"วันนี้วันพระ ขอให้คุณพระศรีรัตนตรัยคุ้มครองให้ร่มเย็นเป็นสุข",
	"ยิ้มรับบุญในวันพระ ขอให้พบเจอแต่สิ่งดีงามและกัลยาณมิตร",
	"จิตที่ฝึกดีแล้วนำสุขมาให้ ขอให้วันพระนี้เป็นวันที่จิตใจผ่องแผ้ว",
}

type BuddhistDayService struct {
	repo ports.BuddhistDayRepository
}

func NewBuddhistDayService(repo ports.BuddhistDayRepository) *BuddhistDayService {
	return &BuddhistDayService{repo: repo}
}

func (s *BuddhistDayService) AddDay(dateStr, title, message string) error {
	date, err := time.Parse("2006-01-02", dateStr)
	if err != nil {
		return err
	}
	day := &domain.BuddhistDay{
		Date:    date,
		Title:   title,
		Message: message,
	}
	return s.repo.Create(day)
}

func (s *BuddhistDayService) UpdateDay(id int, title, message string) error {
	day := &domain.BuddhistDay{
		ID:      id,
		Title:   title,
		Message: message,
	}
	return s.repo.Update(day)
}

func (s *BuddhistDayService) GetAllDays() ([]domain.BuddhistDay, error) {
	days, err := s.repo.GetAll()
	if err != nil {
		return nil, err
	}
	return s.ApplyDefaults(days), nil
}

func (s *BuddhistDayService) GetPaginatedDays(page, pageSize int) ([]domain.BuddhistDay, int, error) {
	offset := (page - 1) * pageSize
	days, total, err := s.repo.GetPaginated(offset, pageSize)
	if err != nil {
		return nil, 0, err
	}
	return s.ApplyDefaults(days), total, nil
}

func (s *BuddhistDayService) DeleteDay(id int) error {
	return s.repo.Delete(id)
}

func (s *BuddhistDayService) GetUpcomingDays(limit int) ([]domain.BuddhistDay, error) {
	days, err := s.repo.GetUpcoming(limit)
	if err != nil {
		return nil, err
	}
	return s.ApplyDefaults(days), nil
}

func (s *BuddhistDayService) ApplyDefaults(days []domain.BuddhistDay) []domain.BuddhistDay {
	for i := range days {
		if days[i].Title == "" {
			days[i].Title = "วันนี้วันพระ"
		}
		if days[i].Message == "" {
			// Use day ID as a seed for consistent "random" message for each day
			msgIndex := days[i].ID % len(defaultBuddhistMessages)
			days[i].Message = defaultBuddhistMessages[msgIndex]
		}
	}
	return days
}

func (s *BuddhistDayService) IsBuddhistDay(date time.Time) (bool, error) {
	// Truncate to midnight safely respecting the timezone of 'date'
	truncated := time.Date(date.Year(), date.Month(), date.Day(), 0, 0, 0, 0, date.Location())

	day, err := s.repo.GetByDate(truncated)
	if err != nil {
		return false, err
	}
	return day != nil, nil
}
