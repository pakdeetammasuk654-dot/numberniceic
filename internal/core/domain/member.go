package domain

// Member represents a user in the system.
type Member struct {
	ID       int    `json:"id"`
	Username string `json:"username"`
	Password string `json:"-"` // The password should not be exposed in JSON responses.
	Email    string `json:"email,omitempty"`
	Tel      string `json:"tel,omitempty"`
	Status   int    `json:"status"`
}
