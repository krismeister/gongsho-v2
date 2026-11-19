-- secrets store contract (writer side: secrets API; reader side: secretsread).
-- Scope is org -> team -> project -> deployment, most specific row wins.
-- A row qualifies its full scope; '' at a level means "this level's
-- baseline": org rows carry team/project/deployment = '', team rows carry
-- project/deployment = '', project rows carry deployment = ''. Slugs
-- repeat across parents (teams per org, projects per team), so every
-- ancestor is always part of the scope — there are no cross-scope rows.
-- value holds opaque single-line ciphertext (base64); readers are blind
-- to its encoding and refuse multiline values. updated is display-only
-- metadata (quoted RFC3339). version is the derivation generation that
-- encrypted value (1 = current); rotation bumps a scope's generation and
-- rows carry theirs, so old values stay readable until re-encrypted.
-- This file is the single source of truth: committed tests build
-- fixtures from it, never from a copy.
CREATE TABLE secrets (
  org TEXT NOT NULL DEFAULT '',
  team TEXT NOT NULL DEFAULT '',
  project TEXT NOT NULL DEFAULT '',
  deployment TEXT NOT NULL DEFAULT '',
  name TEXT NOT NULL,
  value TEXT NOT NULL,
  updated TEXT NOT NULL,
  version INTEGER NOT NULL DEFAULT 1,
  PRIMARY KEY (org, team, project, deployment, name),
  CHECK (org <> ''),
  CHECK (name <> ''),
  CHECK (team <> '' OR (project = '' AND deployment = '')),
  CHECK (project <> '' OR deployment = '')
);
