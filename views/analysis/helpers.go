package analysis

import "fmt"

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
