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
