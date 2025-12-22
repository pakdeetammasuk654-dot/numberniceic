package templ_render

import (
	"github.com/a-h/templ"
	"github.com/gofiber/fiber/v2"
)

// Render is a helper to render a templ component with Fiber
func Render(c *fiber.Ctx, component templ.Component) error {
	c.Set("Content-Type", "text/html")
	return component.Render(c.Context(), c.Response().BodyWriter())
}
