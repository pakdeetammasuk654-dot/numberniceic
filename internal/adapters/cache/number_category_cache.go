package cache

import (
	"numberniceic/internal/core/ports"
	"sync"
)

type NumberCategoryCache struct {
	repository ports.NumberCategoryRepository
	// cache maps a pair number to a slice of categories (since one pair can have multiple categories)
	cache map[string][]string
	// numberTypeCache maps a pair number to its number_type (ดี/ร้าย)
	numberTypeCache map[string]string
	// keywordsCache maps a pair number to its keywords
	keywordsCache map[string][]string
	once          sync.Once
	mu            sync.RWMutex
}

func NewNumberCategoryCache(repository ports.NumberCategoryRepository) *NumberCategoryCache {
	return &NumberCategoryCache{
		repository:      repository,
		cache:           make(map[string][]string),
		numberTypeCache: make(map[string]string),
		keywordsCache:   make(map[string][]string),
	}
}

func (c *NumberCategoryCache) loadCache() error {
	var err error
	c.once.Do(func() {
		categories, loadErr := c.repository.GetAll()
		if loadErr != nil {
			err = loadErr
			return
		}

		c.mu.Lock()
		defer c.mu.Unlock()

		for _, cat := range categories {
			c.cache[cat.PairNumber] = append(c.cache[cat.PairNumber], cat.Category)
			// Store number_type (only once per pair number)
			if _, exists := c.numberTypeCache[cat.PairNumber]; !exists {
				c.numberTypeCache[cat.PairNumber] = cat.NumberType
			}
			// Store keywords (only once per pair number)
			if _, exists := c.keywordsCache[cat.PairNumber]; !exists {
				c.keywordsCache[cat.PairNumber] = cat.Keywords
			}
		}
	})
	return err
}

func (c *NumberCategoryCache) GetCategories(pairNumber string) ([]string, bool) {
	if err := c.loadCache(); err != nil {
		return nil, false
	}

	c.mu.RLock()
	defer c.mu.RUnlock()

	cats, ok := c.cache[pairNumber]
	return cats, ok
}

func (c *NumberCategoryCache) GetNumberType(pairNumber string) string {
	if err := c.loadCache(); err != nil {
		return ""
	}

	c.mu.RLock()
	defer c.mu.RUnlock()

	return c.numberTypeCache[pairNumber]
}

func (c *NumberCategoryCache) GetKeywords(pairNumber string) []string {
	if err := c.loadCache(); err != nil {
		return nil
	}

	c.mu.RLock()
	defer c.mu.RUnlock()

	return c.keywordsCache[pairNumber]
}

func (c *NumberCategoryCache) EnsureLoaded() error {
	return c.loadCache()
}
