package handler

import (
	"numberniceic/internal/adapters/cache"
	"numberniceic/internal/adapters/handler/templ_render"
	"numberniceic/internal/core/domain"
	"numberniceic/internal/core/service"
	"numberniceic/views/pages"
	"strconv"
	"strings"
	"unicode"

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
	var userID int

	// Try JWT first (for mobile app)
	userIDFromJWT := c.Locals("user_id")
	if userIDFromJWT != nil {
		userID = userIDFromJWT.(int)
	} else {
		// Fall back to session (for web)
		sess, _ := h.store.Get(c)
		sessionUserID := sess.Get("member_id")
		if sessionUserID == nil {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "Unauthorized"})
		}
		userID = sessionUserID.(int)
	}

	// Parse form data or JSON
	var name, birthDay string
	var totalScore, satSum, shaSum int

	if strings.HasPrefix(c.Get("Content-Type"), "application/json") {
		// JSON request (mobile app)
		type SaveNameRequest struct {
			Name       string `json:"name"`
			BirthDay   string `json:"birth_day"`
			TotalScore int    `json:"total_score"`
			SatSum     int    `json:"sat_sum"`
			ShaSum     int    `json:"sha_sum"`
		}
		var req SaveNameRequest
		if err := c.BodyParser(&req); err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid request"})
		}
		name = req.Name
		birthDay = req.BirthDay
		totalScore = req.TotalScore
		satSum = req.SatSum
		shaSum = req.ShaSum
	} else {
		// Form data (web)
		name = c.FormValue("name")
		birthDay = c.FormValue("birth_day")
		totalScore, _ = strconv.Atoi(c.FormValue("total_score"))
		satSum, _ = strconv.Atoi(c.FormValue("sat_sum"))
		shaSum, _ = strconv.Atoi(c.FormValue("sha_sum"))
	}

	err := h.service.SaveName(userID, name, birthDay, totalScore, satSum, shaSum)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Could not save name"})
	}

	return c.JSON(fiber.Map{"message": "Name saved successfully!"})
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

		// Calculate IsTopTier (Backend Logic Update to match Frontend)
		isStrictTopTier := h.isAllPairsTopTier(satPairs) && h.isAllPairsTopTier(shaPairs)
		isHighScore := sn.TotalScore >= 50

		// Check for REAL Kalakini (ignoring invisible chars/spaces)
		hasRealKalakini := false
		for _, r := range sn.Name {
			if h.klakiniCache.IsKlakini(sn.BirthDay, r) {
				if !unicode.IsSpace(r) && !unicode.IsControl(r) {
					hasRealKalakini = true
					break
				}
			}
		}

		isTopTier := !hasRealKalakini && (isStrictTopTier || isHighScore)

		// Create DisplayNameHTML
		var displayChars []domain.DisplayChar
		runes := []rune(sn.Name)
		for j := 0; j < len(runes); j++ {
			r := runes[j]
			char := string(r)
			isBad := h.klakiniCache.IsKlakini(sn.BirthDay, r)

			// Check if the next character is a combining mark
			if j+1 < len(runes) && unicode.Is(unicode.Mn, runes[j+1]) {
				combiningChar := runes[j+1]
				isCombiningBad := h.klakiniCache.IsKlakini(sn.BirthDay, combiningChar)

				// If the base is not bad, but the combining mark is
				if !isBad && isCombiningBad {
					// Add the base character as good
					displayChars = append(displayChars, domain.DisplayChar{Char: char, IsBad: false})
					// Add the combining mark as bad
					displayChars = append(displayChars, domain.DisplayChar{Char: string(combiningChar), IsBad: true})
					j++ // Skip the combining mark in the next iteration
					continue
				}
			}

			// Default behavior: add the character with its own klakini status
			displayChars = append(displayChars, domain.DisplayChar{Char: char, IsBad: isBad})
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
		pairType := ""
		if ok {
			color = meaning.Color
			pairType = meaning.PairType
		}
		pairInfos = append(pairInfos, domain.PairInfo{Number: p, Color: color, Type: pairType})
	}
	return pairInfos
}

func (h *SavedNameHandler) DeleteSavedName(c *fiber.Ctx) error {
	var userID int
	isMobile := false

	// Try JWT first
	userIDFromJWT := c.Locals("user_id")
	if userIDFromJWT != nil {
		userID = userIDFromJWT.(int)
		isMobile = true
	} else {
		sess, _ := h.store.Get(c)
		sessionUserID := sess.Get("member_id")
		if sessionUserID == nil {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "Unauthorized"})
		}
		userID = sessionUserID.(int)
	}

	id, _ := strconv.Atoi(c.Params("id"))
	err := h.service.DeleteSavedName(id, userID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Could not delete name"})
	}

	if isMobile || strings.HasPrefix(c.Get("Content-Type"), "application/json") {
		return c.JSON(fiber.Map{"message": "Name deleted successfully"})
	}

	// Fetch updated list to return OOB count and update the table (Web)
	savedNames, err := h.service.GetSavedNames(userID)
	if err != nil {
		return c.SendString("") // Fallback if list fetch fails
	}
	displayNames := h.prepareDisplayNames(savedNames)

	return templ_render.Render(c, pages.SavedNamesList(displayNames))
}
