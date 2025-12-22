package handler

import (
	"numberniceic/internal/adapters/cache"
	"numberniceic/internal/adapters/handler/templ_render"
	"numberniceic/internal/core/domain"
	"numberniceic/internal/core/service"
	"numberniceic/views/pages"
	"strconv"
	"strings"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/session"
)

type SavedNameHandler struct {
	service         *service.SavedNameService
	klakiniCache    *cache.KlakiniCache
	numberPairCache *cache.NumberPairCache
	store           *session.Store
}

func NewSavedNameHandler(service *service.SavedNameService, klakiniCache *cache.KlakiniCache, numberPairCache *cache.NumberPairCache, store *session.Store) *SavedNameHandler {
	return &SavedNameHandler{
		service:         service,
		klakiniCache:    klakiniCache,
		numberPairCache: numberPairCache,
		store:           store,
	}
}

func (h *SavedNameHandler) SaveName(c *fiber.Ctx) error {
	sess, _ := h.store.Get(c)
	userID := sess.Get("member_id")
	if userID == nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "Unauthorized"})
	}

	name := c.FormValue("name")
	birthDay := c.FormValue("birth_day")
	totalScore, _ := strconv.Atoi(c.FormValue("total_score"))
	satSum, _ := strconv.Atoi(c.FormValue("sat_sum"))
	shaSum, _ := strconv.Atoi(c.FormValue("sha_sum"))

	err := h.service.SaveName(userID.(int), name, birthDay, totalScore, satSum, shaSum)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Could not save name"})
	}

	return c.SendString("Name saved successfully!")
}

func (h *SavedNameHandler) GetSavedNames(c *fiber.Ctx) error {
	sess, _ := h.store.Get(c)
	userID := sess.Get("member_id")
	if userID == nil {
		return c.Redirect("/login")
	}

	savedNames, err := h.service.GetSavedNames(userID.(int))
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).SendString("Error loading saved names")
	}

	displayNames := h.prepareDisplayNames(savedNames)

	return templ_render.Render(c, pages.SavedNamesList(displayNames))
}

func (h *SavedNameHandler) prepareDisplayNames(savedNames []domain.SavedName) []domain.SavedNameDisplay {
	displayNames := make([]domain.SavedNameDisplay, len(savedNames))
	for i, sn := range savedNames {
		satPairs := h.getPairsWithColors(sn.SatSum)
		shaPairs := h.getPairsWithColors(sn.ShaSum)

		// Calculate IsTopTier
		isTopTier := h.isAllPairsTopTier(satPairs) && h.isAllPairsTopTier(shaPairs)

		// Create DisplayNameHTML
		var displayChars []domain.DisplayChar
		for _, r := range sn.Name {
			displayChars = append(displayChars, domain.DisplayChar{Char: string(r), IsBad: false})
		}

		displayNames[i] = domain.SavedNameDisplay{
			SavedName:       sn,
			BirthDayThai:    service.GetThaiDay(sn.BirthDay),
			BirthDayRaw:     strings.ToUpper(sn.BirthDay),
			KlakiniChars:    h.getKlakiniChars(sn.Name, sn.BirthDay),
			SatPairs:        satPairs,
			ShaPairs:        shaPairs,
			DisplayNameHTML: displayChars,
			IsTopTier:       isTopTier,
		}
	}
	return displayNames
}

func (h *SavedNameHandler) isAllPairsTopTier(pairs []domain.PairInfo) bool {
	for _, p := range pairs {
		if meaning, ok := h.numberPairCache.GetMeaning(p.Number); ok {
			switch meaning.PairType {
			case "D10", "D8", "D5":
			default:
				return false
			}
		} else {
			return false
		}
	}
	return true
}

func (h *SavedNameHandler) getKlakiniChars(name, day string) []string {
	var klakiniChars []string
	for _, r := range name {
		if h.klakiniCache.IsKlakini(day, r) {
			klakiniChars = append(klakiniChars, string(r))
		}
	}
	return klakiniChars
}

func (h *SavedNameHandler) getPairsWithColors(sum int) []domain.PairInfo {
	s := strconv.Itoa(sum)
	var pairs []string
	if sum < 0 {
		// No pairs for negative sums
	} else if len(s) < 2 {
		pairs = append(pairs, "0"+s)
	} else if len(s) == 2 {
		pairs = append(pairs, s)
	} else { // len(s) > 2
		if len(s)%2 != 0 {
			for i := 0; i < len(s)-1; i++ {
				pairs = append(pairs, s[i:i+2])
			}
		} else {
			for i := 0; i < len(s); i += 2 {
				pairs = append(pairs, s[i:i+2])
			}
		}
	}

	var pairInfos []domain.PairInfo
	for _, p := range pairs {
		meaning, ok := h.numberPairCache.GetMeaning(p)
		color := "#ccc" // Default color
		if ok {
			color = meaning.Color
		}
		pairInfos = append(pairInfos, domain.PairInfo{Number: p, Color: color})
	}
	return pairInfos
}

func (h *SavedNameHandler) DeleteSavedName(c *fiber.Ctx) error {
	sess, _ := h.store.Get(c)
	userID := sess.Get("member_id")
	if userID == nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "Unauthorized"})
	}

	id, _ := strconv.Atoi(c.Params("id"))
	err := h.service.DeleteSavedName(id, userID.(int))
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Could not delete name"})
	}

	return c.SendString("") // Return empty string to remove element from DOM
}
