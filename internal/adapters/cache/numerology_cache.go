package cache

import (
	"numberniceic/internal/core/ports"
	"sync"
)

// NumerologyCache is a generic in-memory cache for numerology-style data.
// It uses the repository pattern to load data on the first access.
type NumerologyCache struct {
	repository ports.NumerologyRepository
	cache      map[string]int
	once       sync.Once
	mu         sync.RWMutex
}

func NewNumerologyCache(repository ports.NumerologyRepository) *NumerologyCache {
	return &NumerologyCache{
		repository: repository,
		cache:      make(map[string]int),
	}
}

// loadCache fetches data from the repository and populates the in-memory cache.
func (c *NumerologyCache) loadCache() error {
	var err error
	c.once.Do(func() {
		numerologies, loadErr := c.repository.GetAll()
		if loadErr != nil {
			err = loadErr
			return
		}

		c.mu.Lock()
		defer c.mu.Unlock()
		for _, n := range numerologies {
			c.cache[n.Character] = n.Value
		}
	})
	return err
}

// GetValue retrieves a single numerology value for a given character from the cache.
func (c *NumerologyCache) GetValue(character string) (int, bool) {
	if err := c.loadCache(); err != nil {
		return 0, false
	}

	c.mu.RLock()
	defer c.mu.RUnlock()
	val, ok := c.cache[character]
	return val, ok
}

// GetAll returns a copy of all cached numerology data.
func (c *NumerologyCache) GetAll() (map[string]int, error) {
	if err := c.loadCache(); err != nil {
		return nil, err
	}

	c.mu.RLock()
	defer c.mu.RUnlock()

	// Return a copy to prevent external modification
	newMap := make(map[string]int)
	for k, v := range c.cache {
		newMap[k] = v
	}
	return newMap, nil
}
