// Command seedtest builds fixture stores for the harness test suite.
// Test-only: never shipped, never built by cache-warm. Verbs must not use
// it — the reader is deliberately read-only, and this is its only writer
// outside the future secrets API.
//
// Usage: seedtest --db PATH --schema PATH [--row org:team:project:deployment:name:value]...
// Values are stored verbatim, so base64 (no ':' or newlines) keeps rows
// unambiguous. Exactly one statement per --schema file is applied.
package main

import (
	"database/sql"
	"flag"
	"fmt"
	"os"
	"strings"

	_ "modernc.org/sqlite"
)

type rows []string

func (r *rows) String() string { return strings.Join(*r, ", ") }

func (r *rows) Set(s string) error {
	parts := strings.SplitN(s, ":", 6)
	if len(parts) != 6 || parts[0] == "" || parts[4] == "" {
		return fmt.Errorf("row wants org:team:project:deployment:name:value, got %q", s)
	}
	if parts[3] != "" && parts[2] == "" {
		return fmt.Errorf("row deployment without project, got %q", s)
	}
	if parts[2] != "" && parts[1] == "" {
		return fmt.Errorf("row project without team, got %q", s)
	}
	if strings.Contains(parts[5], "\n") {
		return fmt.Errorf("row value must be single-line, got %q", s)
	}
	*r = append(*r, s)
	return nil
}

func main() {
	if err := run(); err != nil {
		fmt.Fprintf(os.Stderr, "seedtest: %v\n", err)
		os.Exit(1)
	}
}

func run() error {
	fs := flag.NewFlagSet("seedtest", flag.ContinueOnError)
	dbPath := fs.String("db", "", "store file to create")
	schemaPath := fs.String("schema", "", "schema.sql to apply first")
	var rs rows
	fs.Var(&rs, "row", "org:team:project:deployment:name:value (repeatable)")
	if err := fs.Parse(os.Args[1:]); err != nil {
		return err
	}
	if *dbPath == "" || *schemaPath == "" {
		return fmt.Errorf("want --db and --schema")
	}
	schema, err := os.ReadFile(*schemaPath)
	if err != nil {
		return err
	}
	db, err := sql.Open("sqlite", *dbPath)
	if err != nil {
		return err
	}
	defer db.Close()
	if _, err := db.Exec(string(schema)); err != nil {
		return fmt.Errorf("apply schema: %w", err)
	}
	for _, r := range rs {
		p := strings.SplitN(r, ":", 6)
		if _, err := db.Exec(
			`INSERT INTO secrets (org, team, project, deployment, name, value, updated) VALUES (?, ?, ?, ?, ?, ?, ?)`,
			p[0], p[1], p[2], p[3], p[4], p[5], "2026-11-18T00:00:00Z",
		); err != nil {
			return fmt.Errorf("seed %q: %w", r, err)
		}
	}
	return nil
}
