package service

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"net/url"
	"strings"
	"time"
)

type LinguisticService struct {
	geminiKey    string
	anthropicKey string
	httpClient   *http.Client
}

// --- Gemini Request/Response Structs ---
type GeminiRequest struct {
	Contents []*Content `json:"contents"`
}
type Content struct {
	Parts []*Part `json:"parts"`
}
type Part struct {
	Text string `json:"text"`
}
type GeminiResponse struct {
	Candidates []*Candidate `json:"candidates"`
}
type Candidate struct {
	Content *Content `json:"content"`
}

// --- Anthropic Request/Response Structs ---
type AnthropicMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type AnthropicRequest struct {
	Model     string             `json:"model"`
	MaxTokens int                `json:"max_tokens"`
	Messages  []AnthropicMessage `json:"messages"`
}

type AnthropicResponse struct {
	Content []struct {
		Text string `json:"text"`
	} `json:"content"`
}

func NewLinguisticService(geminiKey, anthropicKey string) (*LinguisticService, error) {
	// Trim keys
	cleanGeminiKey := strings.TrimSpace(geminiKey)
	cleanAnthropicKey := strings.TrimSpace(anthropicKey)

	if cleanGeminiKey == "" && cleanAnthropicKey == "" {
		log.Println("Warning: No AI API Keys provided (Gemini or Anthropic). Linguistic Service will use MOCK data.")
	} else {
		if cleanAnthropicKey != "" {
			log.Println("Info: Anthropic API Key detected. Will prioritize Claude.")
		} else {
			log.Println("Info: Gemini API Key detected. Will use Gemini.")
		}
	}

	return &LinguisticService{
		geminiKey:    cleanGeminiKey,
		anthropicKey: cleanAnthropicKey,
		httpClient: &http.Client{
			Transport: http.DefaultTransport,
			Timeout:   60 * time.Second,
		},
	}, nil
}

func (s *LinguisticService) AnalyzeName(name string) (string, error) {
	// 1. Prioritize Anthropic (Claude) if key exists
	if s.anthropicKey != "" {
		return s.analyzeNameWithClaude(name)
	}

	// 2. Fallback to Gemini if key exists
	if s.geminiKey != "" {
		return s.analyzeNameWithGemini(name)
	}

	// 3. Last Resort: Mock Data
	log.Println("Warning: No API Keys found. Returning mock data.")
	return s.getMockData(name, "No valid API Keys provided"), nil
}

func (s *LinguisticService) analyzeNameWithClaude(name string) (string, error) {
	prompt := fmt.Sprintf(
		"วิเคราะห์ชื่อ '%s' ตามหลักภาษาศาสตร์ไทย โดยไม่ต้องสนใจเรื่องตัวเลขหรือเลขศาสตร์ ให้เน้นที่:\n"+
			"1. รากศัพท์ของแต่ละพยางค์ (ถ้ามี)\n"+
			"2. ความหมายโดยรวมของชื่อ\n"+
			"3. ความรู้สึกหรือภาพลักษณ์ที่ชื่อนี้สื่อถึง (เช่น ความอ่อนโยน, ความเข้มแข็ง, ความทันสมัย)\n"+
			"4. ความเหมาะสมในการใช้เป็นชื่อจริง\n"+
			"สรุปผลการวิเคราะห์ให้กระชับและเข้าใจง่ายในรูปแบบ Markdown (ใช้ bullet points)",
		name,
	)

	// List of models to try
	models := []string{
		"claude-sonnet-4-20250514",   // User specified (New in 2025)
		"claude-3-5-sonnet-latest",   // Best bet in 2026
		"claude-3-5-sonnet-20241022", // New Sonnet
		"claude-3-5-sonnet-20240620", // Old Sonnet
		"claude-3-opus-latest",       // Opus fallback
	}

	for _, model := range models {
		log.Printf("DEBUG: Trying Claude Model: %s", model)

		reqPayload := AnthropicRequest{
			Model:     model,
			MaxTokens: 1024,
			Messages: []AnthropicMessage{
				{Role: "user", Content: prompt},
			},
		}

		reqBody, err := json.Marshal(reqPayload)
		if err != nil {
			return "", fmt.Errorf("failed to marshal anthropic request: %w", err)
		}

		req, err := http.NewRequestWithContext(context.Background(), "POST", "https://api.anthropic.com/v1/messages", bytes.NewBuffer(reqBody))
		if err != nil {
			return "", fmt.Errorf("failed to create anthropic request: %w", err)
		}
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("x-api-key", s.anthropicKey)
		req.Header.Set("anthropic-version", "2023-06-01")

		resp, err := s.httpClient.Do(req)
		if err != nil {
			log.Printf("WARNING: Request to Claude %s failed: %v", model, err)
			continue
		}
		defer resp.Body.Close()

		respBody, err := ioutil.ReadAll(resp.Body)
		if err != nil {
			return "", fmt.Errorf("failed to read anthropic response: %w", err)
		}

		if resp.StatusCode == http.StatusOK {
			var anthropicResp AnthropicResponse
			if err := json.Unmarshal(respBody, &anthropicResp); err != nil {
				log.Printf("Failed to unmarshal success response from %s", model)
				continue
			}
			if len(anthropicResp.Content) > 0 {
				log.Printf("SUCCESS: Used Claude model %s", model)
				return anthropicResp.Content[0].Text, nil
			}
		}

		// If 404 (Model Not Found) or 400 (Bad Request - typically model related), try next
		if resp.StatusCode == http.StatusNotFound || resp.StatusCode == http.StatusBadRequest {
			log.Printf("WARNING: Claude Model %s failed (Status %d): %s. Trying next...", model, resp.StatusCode, string(respBody))
			continue
		}

		// If Auth/Credit error (401, 402, 403), stop immediately and show error
		log.Printf("Claude API Error (Status %d): %s", resp.StatusCode, string(respBody))
		return s.getMockData(name, fmt.Sprintf("Claude API Error (Status %d): %s", resp.StatusCode, string(respBody))), nil
	}

	// If all models fail
	return s.getMockData(name, "All Claude models failed (Not Found/Compatible)"), nil
}

func (s *LinguisticService) analyzeNameWithGemini(name string) (string, error) {
	prompt := fmt.Sprintf(
		"วิเคราะห์ชื่อ '%s' ตามหลักภาษาศาสตร์ไทย โดยไม่ต้องสนใจเรื่องตัวเลขหรือเลขศาสตร์ ให้เน้นที่:\n"+
			"1. รากศัพท์ของแต่ละพยางค์ (ถ้ามี)\n"+
			"2. ความหมายโดยรวมของชื่อ\n"+
			"3. ความรู้สึกหรือภาพลักษณ์ที่ชื่อนี้สื่อถึง (เช่น ความอ่อนโยน, ความเข้มแข็ง, ความทันสมัย)\n"+
			"4. ความเหมาะสมในการใช้เป็นชื่อจริง\n"+
			"สรุปผลการวิเคราะห์ให้กระชับและเข้าใจง่ายในรูปแบบ Markdown (ใช้ bullet points)",
		name,
	)

	reqPayload := GeminiRequest{
		Contents: []*Content{
			{Parts: []*Part{{Text: prompt}}},
		},
	}

	reqBody, err := json.Marshal(reqPayload)
	if err != nil {
		return "", fmt.Errorf("failed to marshal gemini request: %w", err)
	}

	// List of models to try (in order of preference)
	models := []string{
		"gemini-1.5-flash-latest",
		"gemini-1.5-flash-001",
		"gemini-1.5-flash",
		"gemini-1.0-pro",
		"gemini-pro",
	}

	for _, model := range models {
		baseURL := fmt.Sprintf("https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent", model)
		u, _ := url.Parse(baseURL)
		q := u.Query()
		q.Set("key", s.geminiKey)
		u.RawQuery = q.Encode()

		log.Printf("DEBUG: Trying Gemini Model: %s", model)
		req, _ := http.NewRequestWithContext(context.Background(), "POST", u.String(), bytes.NewBuffer(reqBody))
		req.Header.Set("Content-Type", "application/json")

		resp, err := s.httpClient.Do(req)
		if err != nil {
			log.Printf("WARNING: Request to %s failed: %v", model, err)
			continue
		}
		defer resp.Body.Close()

		respBody, _ := ioutil.ReadAll(resp.Body)

		if resp.StatusCode == http.StatusOK {
			var geminiResp GeminiResponse
			if err := json.Unmarshal(respBody, &geminiResp); err == nil && len(geminiResp.Candidates) > 0 && len(geminiResp.Candidates[0].Content.Parts) > 0 {
				return geminiResp.Candidates[0].Content.Parts[0].Text, nil
			}
		} else if resp.StatusCode == http.StatusNotFound {
			continue // Try next model
		} else {
			log.Printf("Gemini API Error (%s): %s", model, string(respBody))
		}
	}

	// If all Gemini models fail, return Mock
	return s.getMockData(name, "All Gemini models failed or API Key invalid"), nil
}

func (s *LinguisticService) getMockData(name, reason string) string {
	return fmt.Sprintf(`
### ผลการวิเคราะห์ (จาก Mock Data)
**ชื่อ:** %s

*   **รากศัพท์:** ข้อมูลจำลอง (Mock Data)
*   **ความหมาย:** ไพเราะและมีความหมายดี (ข้อมูลจำลอง)
*   **พลังของชื่อ:** ส่งเสริมด้านความเมตตาและเสน่ห์ (ข้อมูลจำลอง)
*   **สรุป:** เหมาะสมสำหรับการใช้งาน (ข้อมูลจำลอง)

> *หมายเหตุ: %s*
	`+"\n\n(Generated via Fallback System)", name, reason)
}

func (s *LinguisticService) Close() {
	log.Println("Linguistic service does not require closing.")
}
