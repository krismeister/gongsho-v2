package secrets

import (
	"database/sql"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// fixture builds a store from schema.sql plus w_rows (each row is
// org, team, project, deployment, name, value, updated) and returns a
// read-only handle. A second read-write handle does the seeding,
// mirroring the real writer/reader split.
func fixture(t *testing.T, rows [][7]string) *sql.DB {
	t.Helper()
	schema, err := os.ReadFile("schema.sql")
	if err != nil {
		t.Fatalf("read schema.sql: %v", err)
	}
	path := filepath.Join(t.TempDir(), "s.db")
	w, err := sql.Open("sqlite", path)
	if err != nil {
		t.Fatalf("open writer: %v", err)
	}
	defer w.Close()
	if _, err := w.Exec(string(schema)); err != nil {
		t.Fatalf("apply schema.sql: %v", err)
	}
	for _, r := range rows {
		if _, err := w.Exec(
			`INSERT INTO secrets (org, team, project, deployment, name, value, updated) VALUES (?, ?, ?, ?, ?, ?, ?)`,
			r[0], r[1], r[2], r[3], r[4], r[5], r[6],
		); err != nil {
			t.Fatalf("seed %v: %v", r[:5], err)
		}
	}
	db, err := Open(path)
	if err != nil {
		t.Fatalf("open reader: %v", err)
	}
	t.Cleanup(func() { db.Close() })
	return db
}

func TestLookupPrecedence(t *testing.T) {
	db := fixture(t, [][7]string{
		{"o1", "shop", "todo", "api-1", "LLM_API_KEY", "ZGVwbG95", "2026-11-18T00:00:00Z"},
		{"o1", "shop", "todo", "", "LLM_API_KEY", "cHJvZA==", "2026-11-18T00:00:00Z"},
		{"o1", "shop", "", "", "LLM_API_KEY", "dGVhbQ==", "2026-11-18T00:00:00Z"},
		{"o1", "", "", "", "ROOT_CA", "cm9vdA==", "2026-11-18T00:00:00Z"},
		{"o2", "shop", "todo", "", "LLM_API_KEY", "b3RoZXI=", "2026-11-18T00:00:00Z"},
		{"o1", "shop", "other", "", "ONLY_P", "b25seQ==", "2026-11-18T00:00:00Z"},
	})
	cases := []struct {
		org, team, project, deployment, name, want string
		found                                      bool
	}{
		{"o1", "shop", "todo", "api-1", "LLM_API_KEY", "ZGVwbG95", true}, // deployment wins
		{"o1", "shop", "todo", "api-9", "LLM_API_KEY", "cHJvZA==", true}, // project fallback
		{"o1", "shop", "web", "api-1", "LLM_API_KEY", "dGVhbQ==", true},  // team fallback
		{"o1", "shop", "todo", "", "LLM_API_KEY", "cHJvZA==", true},      // explicit project scope
		{"o1", "shop", "", "", "LLM_API_KEY", "dGVhbQ==", true},          // explicit team scope
		{"o1", "hr", "", "", "ROOT_CA", "cm9vdA==", true},                // org fallback
		{"o1", "", "", "", "ROOT_CA", "cm9vdA==", true},                  // explicit org scope
		{"o2", "shop", "todo", "", "LLM_API_KEY", "b3RoZXI=", true},      // same slugs, other org
		{"o1", "shop", "todo", "", "ONLY_P", "", false},                  // project isolation
		{"o1", "shop", "todo", "api-1", "MISSING", "", false},            // unknown name
		{"o9", "shop", "todo", "", "LLM_API_KEY", "", false},             // unknown org
	}
	for _, c := range cases {
		got, found, err := Lookup(db, c.org, c.team, c.project, c.deployment, c.name)
		if err != nil {
			t.Errorf("Lookup(%q,%q,%q,%q,%q) error: %v", c.org, c.team, c.project, c.deployment, c.name, err)
			continue
		}
		if found != c.found || got != c.want {
			t.Errorf("Lookup(%q,%q,%q,%q,%q) = (%q,%v), want (%q,%v)",
				c.org, c.team, c.project, c.deployment, c.name, got, found, c.want, c.found)
		}
	}
}

func TestLookupValidation(t *testing.T) {
	db := fixture(t, nil)
	for _, args := range [][5]string{
		{"", "shop", "todo", "api-1", "K"},
		{"o1", "shop", "todo", "api-1", ""},
		{"o1", "shop", "", "api-1", "K"},
		{"o1", "", "todo", "", "K"},
		{"  ", "shop", "todo", "", "K"},
	} {
		if _, _, err := Lookup(db, args[0], args[1], args[2], args[3], args[4]); err == nil {
			t.Errorf("Lookup(%q,%q,%q,%q,%q) want error, got nil", args[0], args[1], args[2], args[3], args[4])
		}
	}
}

func TestLookupMultilineRefused(t *testing.T) {
	db := fixture(t, [][7]string{
		{"o1", "shop", "todo", "", "WRAPPED", "Zm9v\nYmFy", "2026-11-18T00:00:00Z"},
	})
	if _, _, err := Lookup(db, "o1", "shop", "todo", "", "WRAPPED"); err == nil {
		t.Error("Lookup of multiline value want error, got nil")
	} else if !strings.Contains(err.Error(), "spans lines") {
		t.Errorf("multiline error = %q, want it to mention line spanning", err)
	}
}

func TestSchemaRejectsBadScope(t *testing.T) {
	path := filepath.Join(t.TempDir(), "s.db")
	w, err := sql.Open("sqlite", path)
	if err != nil {
		t.Fatalf("open writer: %v", err)
	}
	defer w.Close()
	schema, err := os.ReadFile("schema.sql")
	if err != nil {
		t.Fatalf("read schema.sql: %v", err)
	}
	if _, err := w.Exec(string(schema)); err != nil {
		t.Fatalf("apply schema.sql: %v", err)
	}
	for _, row := range [][5]string{
		{"", "shop", "todo", "", "K"},    // cross-org row
		{"o1", "shop", "", "api-1", "K"}, // deployment without project
		{"o1", "", "todo", "", "K"},      // project without team
		{"o1", "shop", "todo", "", ""},   // empty name
	} {
		_, err := w.Exec(
			`INSERT INTO secrets (org, team, project, deployment, name, value, updated) VALUES (?, ?, ?, ?, ?, 'x', 'y')`,
			row[0], row[1], row[2], row[3], row[4],
		)
		if err == nil {
			t.Errorf("INSERT %v want CHECK failure, got nil", row)
		}
	}
}

func TestOpenMissing(t *testing.T) {
	missing := filepath.Join(t.TempDir(), "no.db")
	if _, err := Open(missing); err == nil {
		t.Error("Open(missing) want error, got nil (read-only must not create)")
	}
	if _, err := Open(""); err == nil {
		t.Error("Open(\"\") want error, got nil")
	}
}

func TestOpenEmptyFile(t *testing.T) {
	empty := filepath.Join(t.TempDir(), "e.db")
	if err := os.WriteFile(empty, nil, 0o600); err != nil {
		t.Fatal(err)
	}
	db, err := Open(empty)
	if err != nil {
		t.Fatalf("Open(empty) error: %v (zero-byte file is an empty store)", err)
	}
	defer db.Close()
	if _, _, err := Lookup(db, "o1", "shop", "todo", "", "K"); err == nil {
		t.Error("Lookup on schemaless store want error, got nil")
	}
}

func TestReaderIsReadOnly(t *testing.T) {
	db := fixture(t, nil)
	if _, err := db.Exec(`CREATE TABLE nope (x TEXT)`); err == nil {
		t.Error("DDL through reader want error, got nil (query_only must hold)")
	}
	if _, err := db.Exec(`INSERT INTO secrets VALUES ('o','t','p','','b','c','d',1)`); err == nil {
		t.Error("INSERT through reader want error, got nil (query_only must hold)")
	}
}
