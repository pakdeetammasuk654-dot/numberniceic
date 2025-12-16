package cache

import (
	"numberniceic/internal/core/ports"
	"sync"
)

type KlakiniCache struct {
	repository ports.KlakiniRepository
	// cache maps a day (e.g., "MONDAY") to a map of its bad characters for quick lookups.
	cache map[string]map[rune]bool
	once  sync.Once
	mu    sync.RWMutex
}

func NewKlakiniCache(repository ports.KlakiniRepository) *KlakiniCache {
	return &KlakiniCache{
		repository: repository,
		cache:      make(map[string]map[rune]bool),
	}
}

func (c *KlakiniCache) loadCache() error {
	var err error
	c.once.Do(func() {
		klakinis, loadErr := c.repository.GetAll()
		if loadErr != nil {
			err = loadErr
			return
		}

		c.mu.Lock()
		defer c.mu.Unlock()
		for _, k := range klakinis {
			badCharSet := make(map[rune]bool)
			for _, char := range k.BadChars {
				badCharSet[char] = true
			}
			c.cache[k.Day] = badCharSet
		}
	})
	return err
}

// IsKlakini checks if a character is considered "klakini" for a given day.
func (c *KlakiniCache) IsKlakini(day string, char rune) bool {
	if err := c.loadCache(); err != nil {
		// Handle error, for now, assume not klakini
		return false
	}

	c.mu.RLock()
	defer c.mu.RUnlock()

	if badCharSet, ok := c.cache[day]; ok {
		return badCharSet[char]
	}
	return false
}

// EnsureLoaded pre-warms the cache.
func (c *KlakiniCache) EnsureLoaded() error {
	return c.loadCache()
}
