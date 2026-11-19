// Package secrets resolves org-, team-, project-, and
// deployment-scoped secrets from a SQLite store. Values are opaque
// single-line blobs (base64 ciphertext once the writer side lands);
// this package never decrypts and never alters the store — every open
// is read-only (mode=ro, so a missing file is an error, never a fresh
// database) plus PRAGMA query_only=ON.
//
// Scope precedence: the (org, team, project, deployment, name) row wins,
// then project, then team, then org. Slugs repeat across parents, so
// every ancestor is always part of the scope. The store schema lives in
// schema.sql, which the writer side (secrets API migrations) must match.
package secrets

import (
	"database/sql"
	"fmt"
	"path/filepath"
	"strings"

	_ "modernc.org/sqlite"
)

// Open opens dbPath strictly read-only and fails fast when the file is
// missing or unreadable.
func Open(dbPath string) (*sql.DB, error) {
	if strings.TrimSpace(dbPath) == "" {
		return nil, fmt.Errorf("secrets: empty db path")
	}
	abs, err := filepath.Abs(dbPath)
	if err != nil {
		return nil, fmt.Errorf("secrets: resolve %q: %w", dbPath, err)
	}
	db, err := sql.Open("sqlite", "file:"+abs+"?mode=ro")
	if err != nil {
		return nil, fmt.Errorf("secrets: open %q: %w", abs, err)
	}
	db.SetMaxOpenConns(1)
	if _, err := db.Exec(`PRAGMA busy_timeout = 5000`); err != nil {
		db.Close()
		return nil, fmt.Errorf("secrets: busy_timeout on %q: %w", abs, err)
	}
	if _, err := db.Exec(`PRAGMA query_only = ON`); err != nil {
		db.Close()
		return nil, fmt.Errorf("secrets: query_only on %q: %w", abs, err)
	}
	return db, nil
}

// Lookup returns the stored value for name: the deployment row first,
// then project, then team, then org. An empty team selects org scope;
// a project without a team, or a deployment without a project, is
// malformed and errors. found=false with a nil error means no
// applicable row. Multiline values are refused outright — shell
// consumers capture stdout, and a wrapped value would corrupt sourcing.
func Lookup(db *sql.DB, org, team, project, deployment, name string) (value string, found bool, err error) {
	org = strings.TrimSpace(org)
	team = strings.TrimSpace(team)
	project = strings.TrimSpace(project)
	deployment = strings.TrimSpace(deployment)
	if org == "" {
		return "", false, fmt.Errorf("secrets: empty org")
	}
	if strings.TrimSpace(name) == "" {
		return "", false, fmt.Errorf("secrets: empty name")
	}
	if deployment != "" && project == "" {
		return "", false, fmt.Errorf("secrets: deployment without project")
	}
	if project != "" && team == "" {
		return "", false, fmt.Errorf("secrets: project without team")
	}
	if deployment != "" {
		v, ok, err := query(db, org, team, project, deployment, name)
		if err != nil || ok {
			return v, ok, err
		}
	}
	if project != "" {
		v, ok, err := query(db, org, team, project, "", name)
		if err != nil || ok {
			return v, ok, err
		}
	}
	if team != "" {
		v, ok, err := query(db, org, team, "", "", name)
		if err != nil || ok {
			return v, ok, err
		}
	}
	return query(db, org, "", "", "", name)
}

func query(db *sql.DB, org, team, project, deployment, name string) (string, bool, error) {
	var v string
	err := db.QueryRow(
		`SELECT value FROM secrets WHERE org = ? AND team = ? AND project = ? AND deployment = ? AND name = ?`,
		org, team, project, deployment, name,
	).Scan(&v)
	if err == sql.ErrNoRows {
		return "", false, nil
	}
	if err != nil {
		return "", false, fmt.Errorf("secrets: lookup %s/%s/%s/%s/%s: %w", org, team, project, deployment, name, err)
	}
	if strings.Contains(v, "\n") {
		return "", false, fmt.Errorf("secrets: value for %s/%s/%s/%s/%s spans lines (refusing multiline output)", org, team, project, deployment, name)
	}
	return v, true, nil
}
