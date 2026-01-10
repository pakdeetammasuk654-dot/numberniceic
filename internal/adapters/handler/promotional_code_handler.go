package handler

import (
	"log"
	"numberniceic/internal/adapters/repository"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/session"
)

type PromotionalCodeHandler struct {
	repo  *repository.PostgresPromotionalCodeRepository
	store *session.Store
}

func NewPromotionalCodeHandler(repo *repository.PostgresPromotionalCodeRepository, store *session.Store) *PromotionalCodeHandler {
	return &PromotionalCodeHandler{
		repo:  repo,
		store: store,
	}
}

func (h *PromotionalCodeHandler) RedeemCode(c *fiber.Ctx) error {
	type RedeemRequest struct {
		Code string `json:"code"`
	}

	var req RedeemRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid request"})
	}

	if req.Code == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Code is required"})
	}

	// Identify User (JWT or Session)
	var memberID int
	if uid := c.Locals("user_id"); uid != nil {
		memberID = uid.(int)
	} else {
		sess, _ := h.store.Get(c)
		if mid, ok := sess.Get("member_id").(int); ok {
			memberID = mid
		} else {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "Unauthorized"})
		}
	}

	// 1. Fetch code
	pc, err := h.repo.GetByCode(req.Code)
	if err != nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "ไม่พบโค้ดนี้ในระบบ"})
	}

	if pc.IsUsed {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "โค้ดนี้ถูกใช้งานไปแล้ว"})
	}

	// 2. Redeem and Upgrade
	err = h.repo.Redeem(pc.ID, memberID)
	if err != nil {
		log.Printf("Redeem Error: %v", err)
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "เกิดข้อผิดพลาดในการเปิดใช้งาน VIP"})
	}

	// Update session if using session
	sess, _ := h.store.Get(c)
	sess.Set("is_vip", true)
	sess.Save()

	return c.JSON(fiber.Map{
		"message": "ยินดีด้วย! คุณได้รับการอัปเกรดเป็น VIP เรียบร้อยแล้ว",
		"status":  "success",
	})
}

func (h *PromotionalCodeHandler) GenerateMockCode(c *fiber.Ctx) error {
	// Simple random code generator
	const charset = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	seed := time.Now().UnixNano()
	code := ""
	for i := 0; i < 8; i++ {
		code += string(charset[seed%int64(len(charset))])
		seed = seed / int64(len(charset))
	}

	err := h.repo.GenerateCode(code)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Failed to generate code"})
	}

	return c.JSON(fiber.Map{"code": code})
}

func (h *PromotionalCodeHandler) BuyProduct(c *fiber.Ctx) error {
	type BuyRequest struct {
		ProductName string `json:"product_name"`
	}

	var req BuyRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "Invalid request"})
	}

	// Identify User (JWT or Session)
	var memberID int
	if uid := c.Locals("user_id"); uid != nil {
		memberID = uid.(int)
	} else {
		sess, _ := h.store.Get(c)
		if mid, ok := sess.Get("member_id").(int); ok {
			memberID = mid
		} else {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "Unauthorized"})
		}
	}

	// Simple random code generator
	const charset = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	seed := time.Now().UnixNano()
	code := ""
	for i := 0; i < 8; i++ {
		code += string(charset[seed%int64(len(charset))])
		seed = seed / int64(len(charset))
	}

	_, err := h.repo.CreatePurchase(code, memberID, req.ProductName)
	if err != nil {
		log.Printf("Purchase Error: %v", err)
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Failed to process purchase"})
	}

	return c.JSON(fiber.Map{"code": code, "message": "สั่งซื้อสำเร็จ! รหัส VIP ถูกนำเข้าสู่แดชบอร์ดของคุณแล้ว"})
}
