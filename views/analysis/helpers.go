package analysis

import (
	"fmt"
	"numberniceic/internal/core/domain"
	"strings"
)

// add sums two integers.
func add(a, b int) int {
	return a + b
}

// div performs division with zero check.
func div(a, b float64) float64 {
	if b == 0 {
		return 0
	}
	return a / b
}

// mul multiplies two float64 numbers.
func mul(a, b float64) float64 {
	return a * b
}

// printf is a wrapper for fmt.Sprintf
func printf(f string, v ...interface{}) string {
	return fmt.Sprintf(f, v...)
}

// ifThen returns a if cond is true, else b.
func ifThen(cond bool, a, b string) string {
	if cond {
		return a
	}
	return b
}

// getSaveButtonVisibility returns style for save button visibility
func getSaveButtonVisibility(isVIP bool) string {
	if isVIP {
		return "display: flex;"
	}
	return "display: none !important;"
}

// getPercentColor returns hex color based on percentage
func getPercentColor(p float64) string {
	if p >= 75 {
		return "#10B981" // Green
	}
	if p >= 50 {
		return "#F59E0B" // Orange
	}
	return "#EF4444" // Red
}

func hasBadInSummaries(summaries []domain.AnalysisSummary) bool {
	for _, s := range summaries {
		if strings.Contains(s.Title, "ส่งผลร้าย") {
			return true
		}
		for _, content := range s.Content {
			if content.IsBad {
				return true
			}
		}
	}
	return false
}

// translateDay converts English day names to Thai.
func translateDay(day string) string {
	day = strings.ToLower(strings.TrimSpace(day))
	switch day {
	case "sunday":
		return "วันอาทิตย์"
	case "monday":
		return "วันจันทร์"
	case "tuesday":
		return "วันอังคาร"
	case "wednesday":
		return "วันพุธ"
	case "wednesday night":
		return "วันพุธกลางคืน"
	case "thursday":
		return "วันพฤหัสบดี"
	case "friday":
		return "วันศุกร์"
	case "saturday":
		return "วันเสาร์"
	default:
		return day
	}
}
