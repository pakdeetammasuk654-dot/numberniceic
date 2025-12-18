package cache

import (
	"numberniceic/internal/adapters/repository"
	"numberniceic/internal/core/domain"
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
