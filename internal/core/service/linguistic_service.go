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
	apiKey     string
	httpClient *http.Client
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

func NewLinguisticService(apiKey string) (*LinguisticService, error) {
	// Trim any whitespace from the API key
	cleanKey := strings.TrimSpace(apiKey)

	if cleanKey == "" {
		return nil, fmt.Errorf("API key is empty")
	}

	return &LinguisticService{
		apiKey: cleanKey,
		httpClient: &http.Client{
			// Use the default transport which handles DNS, TLS, etc. correctly.
			Transport: http.DefaultTransport,
			Timeout:   60 * time.Second,
		},
	}, nil
}

func (s *LinguisticService) AnalyzeName(name string) (string, error) {
	if s.apiKey == "" {
		return "", fmt.Errorf("API key is missing in service struct")
	}

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
			{
				Parts: []*Part{
					{Text: prompt},
				},
			},
		},
	}

	reqBody, err := json.Marshal(reqPayload)
	if err != nil {
		return "", fmt.Errorf("failed to marshal request body: %w", err)
	}

	// Construct the URL safely using url.URL
	baseURL := "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"
	u, err := url.Parse(baseURL)
	if err != nil {
		return "", fmt.Errorf("failed to parse base URL: %w", err)
	}
	q := u.Query()
	q.Set("key", s.apiKey)
	u.RawQuery = q.Encode()

	finalURL := u.String()

	req, err := http.NewRequestWithContext(context.Background(), "POST", finalURL, bytes.NewBuffer(reqBody))
	if err != nil {
		return "", fmt.Errorf("failed to create http request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("failed to send http request: %w", err)
	}
	defer resp.Body.Close()

	respBody, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("failed to read response body: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("gemini api request failed with status %d: %s", resp.StatusCode, string(respBody))
	}

	var geminiResp GeminiResponse
	if err := json.Unmarshal(respBody, &geminiResp); err != nil {
		return "", fmt.Errorf("failed to unmarshal response body: %w", err)
	}

	if len(geminiResp.Candidates) > 0 && len(geminiResp.Candidates[0].Content.Parts) > 0 {
		return geminiResp.Candidates[0].Content.Parts[0].Text, nil
	}

	return "ไม่สามารถวิเคราะห์ได้ในขณะนี้ (No content generated)", nil
}

func (s *LinguisticService) Close() {
	log.Println("Linguistic service does not require closing.")
}
