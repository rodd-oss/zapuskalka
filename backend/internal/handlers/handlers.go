package handlers

import (
	"log/slog"
	"net/http"

	"github.com/romsar/gonertia"
)

type Handler struct {
	inertia *gonertia.Inertia
	logger  *slog.Logger
}

func New(inertia *gonertia.Inertia, logger *slog.Logger) *Handler {
	return &Handler{
		inertia: inertia,
		logger:  logger,
	}
}

func (h *Handler) Home() http.Handler {
	fn := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if err := h.inertia.Render(w, r, "Home"); err != nil {
			h.logger.Error("failed to render page", "page", "Home", "error", err)
			http.Error(w, "Internal Server Error", http.StatusInternalServerError)
			return
		}
	})

	return h.middleware(fn)
}

func (h *Handler) Login() http.Handler {
	fn := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if err := h.inertia.Render(w, r, "Login"); err != nil {
			h.logger.Error("failed to render page",
				"page", "Login",
				"error", err,
			)
			http.Error(w, "Internal Server Error", http.StatusInternalServerError)
			return
		}
	})

	return h.middleware(fn)
}

func (h *Handler) OAuthCallback() http.Handler {
	fn := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		q := r.URL.Query()

		props := gonertia.Props{
			"code":  q.Get("code"),
			"scope": q.Get("scope"),
			"state": q.Get("state"),
		}

		if err := h.inertia.Render(w, r, "OAuthCallback", props); err != nil {
			h.logger.Error("failed to render page",
				"page", "OAuthCallback",
				"error", err,
			)
			http.Error(w, "Internal Server Error", http.StatusInternalServerError)
			return
		}
	})

	return h.middleware(fn)
}

func (h *Handler) middleware(handler http.Handler) http.Handler {
	return h.inertia.Middleware(handler)
}
