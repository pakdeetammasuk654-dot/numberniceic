package handler

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strconv"
	"time"

	"numberniceic/internal/adapters/handler/templ_render"
	"numberniceic/internal/core/service"
	"numberniceic/views/payment"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/session"
)

type PaymentHandler struct {
	service *service.PaymentService
	store   *session.Store
}

func NewPaymentHandler(service *service.PaymentService, store *session.Store) *PaymentHandler {
	return &PaymentHandler{
		service: service,
		store:   store,
	}
}

// PaySolutions Request Struct
type PromptPayRequest struct {
	MerchantID    string  `json:"merchantID"`
	ProductDetail string  `json:"productDetail"`
	CustomerEmail string  `json:"customerEmail"`
	CustomerName  string  `json:"customerName"`
	Total         float64 `json:"total"` // Changed to float64 for numeric/decimal requirement
	ReferenceNo   string  `json:"referenceNo"`
}

// GetUpgradeModal renders the payment modal with a generated unique PromptPay QR
func (h *PaymentHandler) GetUpgradeModal(c *fiber.Ctx) error {
	merchantID := os.Getenv("MERCHANT_ID")
	apiKey := os.Getenv("API_KEY")

	// 1. Identify User
	sess, _ := h.store.Get(c)
	var userID *int
	if uid, ok := sess.Get("member_id").(int); ok {
		userID = &uid
	} else {
		// FORCE LOGIN: Redirect to /login if not logged in
		c.Set("HX-Redirect", "/login")
		return c.SendStatus(fiber.StatusUnauthorized)
	}

	// 2. Generate Unique Ref No
	refNo := fmt.Sprintf("%d", time.Now().UnixNano())
	if len(refNo) > 12 {
		refNo = refNo[len(refNo)-12:]
	}

	amount := 599.00 // VIP Price 599 THB Lifetime

	// 3. Create Order in Database
	err := h.service.CreateOrder(refNo, amount, userID)
	if err != nil {
		log.Printf("Error creating order: %v", err)
	} else {
		log.Printf("✅ Order Created. RefNo: %s | UserID: %v | Amount: %.2f", refNo, userID, amount)
	}

	if merchantID == "" || apiKey == "" {
		log.Println("Warning: PaySolutions Credentials missing. Using Mock Mode.")
		return templ_render.Render(c, payment.UpgradeModal("", refNo))
	}

	// Payload - PaySolutions V2 Docs: Parameters via Query String, Auth via Header
	baseURL := "https://apis.paysolutions.asia/tep/api/v2/promptpaynew"

	req, err := http.NewRequest("POST", baseURL, nil) // No Body
	if err != nil {
		log.Println("Error creating request:", err)
		return templ_render.Render(c, payment.UpgradeModal("", refNo))
	}

	// Add Query Parameters
	q := req.URL.Query()
	q.Add("merchantID", merchantID)
	q.Add("productDetail", "VIP Upgrade")
	q.Add("customerEmail", "guest@example.com")
	q.Add("customerName", "Guest User")
	q.Add("total", fmt.Sprintf("%.2f", amount))
	q.Add("referenceNo", refNo)

	// Dynamically send POST_BACK_URL from .env to PaySolutions
	postbackURL := os.Getenv("POST_BACK_URL")
	if postbackURL != "" {
		q.Add("postbackurl", postbackURL)
		log.Printf("DEBUG: Including postbackurl: %s", postbackURL)
	}

	req.URL.RawQuery = q.Encode()

	log.Printf("DEBUG: Sending PaySolutions Request (Query). URL: %s", req.URL.String())

	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	req.Header.Set("Accept", "application/json")
	req.Header.Set("Authorization", "Bearer "+apiKey) // Correct Long Auth Key

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		log.Println("Error calling PaySolutions:", err)
		return templ_render.Render(c, payment.UpgradeModal("", refNo))
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	log.Printf("PaySolutions Response: %s", string(body))

	var resultMap map[string]interface{}
	if err := json.Unmarshal(body, &resultMap); err != nil {
		log.Println("Error parsing response JSON:", err)
		return templ_render.Render(c, payment.UpgradeModal("", refNo))
	}

	var qrBase64 string

	// Check if "data" field exists and is a map
	if dataMap, ok := resultMap["data"].(map[string]interface{}); ok {
		if val, ok := dataMap["image"].(string); ok {
			qrBase64 = val
		}
	} else if val, ok := resultMap["image"].(string); ok {
		// Fallback for some other formats
		qrBase64 = val
	}

	if qrBase64 != "" && len(qrBase64) > 0 {
		if !bytes.HasPrefix([]byte(qrBase64), []byte("data:image")) {
			qrBase64 = "data:image/png;base64," + qrBase64
		}
	} else {
		log.Println("Warning: No QR data found in response")
	}

	return templ_render.Render(c, payment.UpgradeModal(qrBase64, refNo))
}

// SimulatePaymentSuccess handles the mock success action
func (h *PaymentHandler) SimulatePaymentSuccess(c *fiber.Ctx) error {
	// 1. Set a cookie to remember VIP status (Legacy Mock method)
	cookie := new(fiber.Cookie)
	cookie.Name = "vip_status"
	cookie.Value = "active"
	cookie.Expires = time.Now().Add(24 * time.Hour * 365)
	cookie.HTTPOnly = true
	cookie.SameSite = "Lax"

	c.Cookie(cookie)

	// In real app, we might also want to upgrade the user here if they are logged in, just in case.
	// But usually this button is for "Simulating" the callback.
	// The Webhook handles the real logic.

	return templ_render.Render(c, payment.PaymentSuccess())
}

// ResetPayment clears VIP status (helper for dev)
func (h *PaymentHandler) ResetPayment(c *fiber.Ctx) error {
	c.ClearCookie("vip_status")
	return c.Redirect("/")
}

// HandlePaymentWebhook processes the server-to-server postback from PaySolutions
func (h *PaymentHandler) HandlePaymentWebhook(c *fiber.Ctx) error {
	// PaySolutions sends data as Form URL Encoded or JSON
	refNo := c.FormValue("refno")
	// merchantID := c.FormValue("merchantid")
	status := c.FormValue("status")
	totalStr := c.FormValue("total")

	total, _ := strconv.ParseFloat(totalStr, 64)

	log.Printf("💰 PAYMENT WEBHOOK RECEIVED 💰 | Ref: %s | Status: %s | Total: %.2f", refNo, status, total)

	// Process Payment via Service
	err := h.service.ProcessPaymentSuccess(refNo, total)
	if err != nil {
		log.Printf("❌ Error processing payment success: %v", err)
		// We might return non-200 to tell PaySolutions to retry?
		// Or assume it's done.
	} else {
		log.Printf("✅ Payment Processed Successfully. User Upgraded.")
	}

	return c.SendString("OK")
}

// CheckPaymentStatus checks if the order is paid and returns the success UI if so
func (h *PaymentHandler) CheckPaymentStatus(c *fiber.Ctx) error {
	refNo := c.Params("refNo")

	order, err := h.service.GetOrder(refNo)
	if err != nil {
		// handle error or not found
		return c.SendStatus(fiber.StatusNotFound)
	}

	if order.Status == "paid" {
		// Log
		log.Printf("DEBUG: Polling - Order %s is PAID. Returning Success UI.", refNo)
		// Return the Success Component HTML
		return templ_render.Render(c, payment.PaymentSuccess())
	}

	// Still pending
	return c.SendStatus(fiber.StatusNoContent)
}
