package cache

import (
	"numberniceic/internal/core/domain"
	"numberniceic/internal/core/ports"
	"sync"
)

type NumberPairCache struct {
	repository ports.NumberPairRepository
	// cache maps a pair number (e.g., "12") to its meaning.
	cache map[string]domain.NumberPairMeaning
	once  sync.Once
	mu    sync.RWMutex
}

func NewNumberPairCache(repository ports.NumberPairRepository) *NumberPairCache {
	return &NumberPairCache{
		repository: repository,
		cache:      make(map[string]domain.NumberPairMeaning),
	}
}

func (c *NumberPairCache) loadCache() error {
	var err error
	c.once.Do(func() {
		meanings, loadErr := c.repository.GetAll()
		if loadErr != nil {
			err = loadErr
			return
		}

		c.mu.Lock()
		defer c.mu.Unlock()

		for _, m := range meanings {
			c.cache[m.PairNumber] = m
		}
	})
	return err
}

// GetMeaning retrieves the meaning for a given pair number.
func (c *NumberPairCache) GetMeaning(pairNumber string) (domain.NumberPairMeaning, bool) {
	if err := c.loadCache(); err != nil {
		return domain.NumberPairMeaning{}, false
	}

	c.mu.RLock()
	defer c.mu.RUnlock()

	meaning, ok := c.cache[pairNumber]
	return meaning, ok
}

// GetAllMeanings returns a copy of the entire cache map.
func (c *NumberPairCache) GetAllMeanings() (map[string]domain.NumberPairMeaning, error) {
	if err := c.loadCache(); err != nil {
		return nil, err
	}

	c.mu.RLock()
	defer c.mu.RUnlock()

	// Return a copy to prevent external modification
	newMap := make(map[string]domain.NumberPairMeaning, len(c.cache))
	for k, v := range c.cache {
		newMap[k] = v
	}
	return newMap, nil
}

// EnsureLoaded pre-warms the cache.
func (c *NumberPairCache) EnsureLoaded() error {
	return c.loadCache()
}
