// Command secretsread prints one stored secret value for the harness verbs.
//
// Usage: secretsread --db PATH --org ORG --name NAME [--team TEAM] [--project PROJECT] [--deployment DEP]
//
// An empty team selects org scope; a project without a team, or a
// deployment without a project, is malformed. Stdout carries only the
// value (plus a trailing newline); diagnostics go to stderr. Exit 0 on
// a hit, 1 on any operational failure (missing file, unknown secret,
// unreadable store), 2 on usage errors.
package main

import (
	"flag"
	"fmt"
	"os"

	"gongsho/tools/secretsread/secrets"
)

func usage() {
	fmt.Fprintf(os.Stderr, "usage: secretsread --db PATH --org ORG --name NAME [--team TEAM] [--project PROJECT] [--deployment DEP]\n")
}

func main() {
	if err := run(); err != nil {
		fmt.Fprintf(os.Stderr, "secretsread: %v\n", err)
		os.Exit(1)
	}
}

func run() error {
	fs := flag.NewFlagSet("secretsread", flag.ContinueOnError)
	fs.Usage = usage
	dbPath := fs.String("db", "", "SQLite store file (read-only open)")
	org := fs.String("org", "", "org scope (always required)")
	team := fs.String("team", "", "team scope (empty selects the org row)")
	project := fs.String("project", "", "project scope (empty selects the team row)")
	deployment := fs.String("deployment", "", "deployment scope (empty selects the project row)")
	name := fs.String("name", "", "secret name")
	if err := fs.Parse(os.Args[1:]); err != nil {
		if err == flag.ErrHelp {
			os.Exit(0)
		}
		os.Exit(2)
	}
	if *dbPath == "" || *org == "" || *name == "" {
		usage()
		os.Exit(2)
	}
	if fs.NArg() > 0 {
		usage()
		os.Exit(2)
	}
	db, err := secrets.Open(*dbPath)
	if err != nil {
		return err
	}
	defer db.Close()
	value, found, err := secrets.Lookup(db, *org, *team, *project, *deployment, *name)
	if err != nil {
		return err
	}
	if !found {
		return fmt.Errorf("no secret %q for %s/%s/%s/%s", *name, *org, *team, *project, *deployment)
	}
	fmt.Println(value)
	return nil
}
