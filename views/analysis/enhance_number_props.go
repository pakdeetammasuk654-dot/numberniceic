package analysis

import "numberniceic/internal/core/domain"

type EnhanceNumberProps struct {
	Layout                LayoutProps
	CleanedName           string
	InputDay              string
	SolarSystem           SolarSystemProps
	DisplayNameHTML       []domain.DisplayChar
	HeaderDisplayNameHTML []domain.DisplayChar
	IsVIP                 bool
}
