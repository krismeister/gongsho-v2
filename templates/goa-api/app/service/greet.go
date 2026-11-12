// Package service implements the example greet service behind the generated
// interfaces in gen/greet. It is app-owned: extend or replace it as the
// design grows.
package service

import (
	"context"
	"database/sql"
	"fmt"
	"os"

	"gongsho/template/goa-api/gen/greet"
)

// Deployment env keys (injected by start; see .example.env).
const (
	envID              = "DEPLOYMENT_ID"
	envTemplate        = "TEMPLATE"
	envTemplateVersion = "TEMPLATE_VERSION"
)

// Greet implements greet.Service. It reads the greeting word from the
// app_constants table seeded by migrations/0001_init.
type Greet struct {
	db *sql.DB
}

// NewGreet returns a greet.Service backed by db.
func NewGreet(db *sql.DB) greet.Service {
	return &Greet{db: db}
}

// Hello implements greet.Service.
func (s *Greet) Hello(ctx context.Context, name string) (*greet.HelloResult, error) {
	var word string
	err := s.db.QueryRowContext(ctx, "SELECT value FROM app_constants WHERE key = ?", "greeting").Scan(&word)
	if err != nil {
		return nil, fmt.Errorf("greet: read greeting constant: %w", err)
	}
	return &greet.HelloResult{Greeting: word + " " + name}, nil
}

// Info describes this deployment. Served at GET /info.
type Info struct {
	ID              string `json:"id"`
	Template        string `json:"template"`
	TemplateVersion string `json:"templateVersion"`
}

// DeploymentInfo returns this deployment's identity from the environment.
func DeploymentInfo() Info {
	return Info{
		ID:              os.Getenv(envID),
		Template:        os.Getenv(envTemplate),
		TemplateVersion: os.Getenv(envTemplateVersion),
	}
}

// CheckDeploymentEnv fails when any identity variable is missing.
func CheckDeploymentEnv() error {
	for _, key := range []string{envID, envTemplate, envTemplateVersion} {
		if os.Getenv(key) == "" {
			return fmt.Errorf("missing required %s (injected by start)", key)
		}
	}
	return nil
}
