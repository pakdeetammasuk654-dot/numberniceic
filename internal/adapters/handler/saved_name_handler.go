package handler

import (
	"numberniceic/internal/core/service"
	"strconv"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/session"
)

type SavedNameHandler struct {
	service *service.SavedNameService
	store   *session.Store
}

func NewSavedNameHandler(service *service.SavedNameService, store *session.Store) *SavedNameHandler {
	return &SavedNameHandler{
		service: service,
		store:   store,
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

	return c.Render("partials/saved_names_list", fiber.Map{
		"SavedNames": savedNames,
	})
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
