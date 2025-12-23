package cache

import (
	"numberniceic/internal/adapters/repository"
	"numberniceic/internal/core/domain"
	"strings"
	"sync"
)

type SampleNamesCache struct {
	repo        *repository.PostgresSampleNamesRepository
	sampleNames []domain.SampleName
	mu          sync.RWMutex
	loaded      bool
}

func NewSampleNamesCache(repo *repository.PostgresSampleNamesRepository) *SampleNamesCache {
	return &SampleNamesCache{
		repo: repo,
	}
}

func (c *SampleNamesCache) Reload() error {
	c.mu.Lock()
	c.loaded = false
	c.mu.Unlock()
	return c.EnsureLoaded()
}

func (c *SampleNamesCache) EnsureLoaded() error {
	c.mu.Lock()
	defer c.mu.Unlock()

	if c.loaded {
		return nil
	}

	sampleNames, err := c.repo.GetAll()
	if err != nil {
		return err
	}

	// Logic:
	// 1. Find if any record has IsActive == true -> Move to front.
	// 2. If no IsActive == true -> Find "ปัญญา" -> Move to front.
	// 3. Fallback -> Just use the list.

	activeIndex := -1
	panyaIndex := -1

	for i, name := range sampleNames {
		if name.IsActive {
			activeIndex = i
			break // Priority 1 found
		}
		if strings.TrimSpace(name.Name) == "ปัญญา" {
			panyaIndex = i
			sampleNames[i].Name = "ปัญญา" // Normalize
		}
	}

	if activeIndex != -1 {
		// Found active record
		if activeIndex > 0 {
			// Swap
			sampleNames[0], sampleNames[activeIndex] = sampleNames[activeIndex], sampleNames[0]
		}
	} else if panyaIndex != -1 {
		// Fallback to Panya
		if panyaIndex > 0 {
			sampleNames[0], sampleNames[panyaIndex] = sampleNames[panyaIndex], sampleNames[0]
		}
	} else {
		// Optional: If "ปัญญา" is critically required but missing, insert it?
		// For now, assume DB is managed by Admin.
		// Previous fallback code inserted it. We can keep it if desired, but
		// "IsActive" system implies DB control. Let's keep it safe.
		// If list is empty?
		if len(sampleNames) == 0 {
			// Maybe insert default?
			// Let's rely on DB for now.
		} else {
			// Check if we should insert Panya if missing?
			// Providing a "system" usually implies we stop hardcoding.
			// But to prevent regression of "Panya not active" if DB is untouched (IsActive all false),
			// the above `if panyaIndex != -1` handles it.
			// If Panya is MISSING from DB entirely, should we add it?
			// Let's add it if missing and no active found.
			panya := domain.SampleName{
				Name:      "ปัญญา",
				AvatarURL: "/static/images/samples/1.png",
				IsActive:  true, // Artificial active?
			}
			sampleNames = append([]domain.SampleName{panya}, sampleNames...)
		}
	}

	c.sampleNames = sampleNames
	c.loaded = true
	return nil
}

func (c *SampleNamesCache) GetAll() ([]domain.SampleName, error) {
	if err := c.EnsureLoaded(); err != nil {
		return nil, err
	}

	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.sampleNames, nil
}
