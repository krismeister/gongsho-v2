// Package e2e holds the template's HTTP flow tests. The harness runs them
// with `go test ./e2e/` after exporting E2E_BASE_URL or E2E_APP_<ID>
// pointing at the deployment under test (see docs/phase-1/e2e-standard.md).
// The tests never hardcode addresses.
package e2e

import (
	"encoding/json"
	"io"
	"net/http"
	"net/url"
	"os"
	"regexp"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// versionRe matches a wellformed two-part template version ("1.0").
var versionRe = regexp.MustCompile(`^[0-9]+\.[0-9]+$`)

// baseURL resolves the deployment under test: the single E2E_APP_* value when
// exactly one is set, else E2E_BASE_URL.
func baseURL(t *testing.T) string {
	t.Helper()
	var found []string
	for _, kv := range os.Environ() {
		name, value, _ := strings.Cut(kv, "=")
		if strings.HasPrefix(name, "E2E_APP_") {
			found = append(found, value)
		}
	}
	if len(found) == 1 {
		return strings.TrimSuffix(found[0], "/")
	}
	base := strings.TrimSuffix(os.Getenv("E2E_BASE_URL"), "/")
	require.NotEmpty(t, base, "set E2E_BASE_URL or exactly one E2E_APP_<ID> variable")
	if len(found) > 1 {
		require.Fail(t, "multiple E2E_APP_* variables set; test one deployment per run")
	}
	return base
}

// expectedID derives the deployment ID from the request URL: the last three
// path segments (team/project/deployment) joined with underscores.
func expectedID(t *testing.T, base string) string {
	t.Helper()
	u, err := url.Parse(base)
	require.NoError(t, err, "parse base URL")
	segs := strings.Split(strings.Trim(u.Path, "/"), "/")
	require.GreaterOrEqual(t, len(segs), 3, "base URL path carries team/project/deployment")
	return strings.Join(segs[len(segs)-3:], "_")
}

func get(t *testing.T, client *http.Client, url string) (int, string, http.Header) {
	t.Helper()
	resp, err := client.Get(url)
	require.NoError(t, err, "GET %s", url)
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	require.NoError(t, err, "read %s", url)
	return resp.StatusCode, string(body), resp.Header
}

func client() *http.Client {
	return &http.Client{Timeout: 10 * time.Second}
}

// TestHealthz checks the liveness endpoint.
func TestHealthz(t *testing.T) {
	status, body, _ := get(t, client(), baseURL(t)+"/healthz")
	assert.Equal(t, http.StatusOK, status, "GET /healthz status")
	var health map[string]string
	if assert.NoError(t, json.Unmarshal([]byte(body), &health), "GET /healthz body is JSON") {
		assert.Equal(t, map[string]string{"status": "ok"}, health, "GET /healthz body")
	}
}

// TestOpenAPI checks the served spec.
func TestOpenAPI(t *testing.T) {
	status, body, header := get(t, client(), baseURL(t)+"/openapi.json")
	assert.Equal(t, http.StatusOK, status, "GET /openapi.json status")
	assert.Contains(t, header.Get("Content-Type"), "application/json", "GET /openapi.json content type")
	var spec map[string]any
	if assert.NoError(t, json.Unmarshal([]byte(body), &spec), "GET /openapi.json body is JSON") {
		version, _ := spec["openapi"].(string)
		assert.True(t, strings.HasPrefix(version, "3.0"), "spec is OpenAPI 3.0, got %q", version)
		paths, _ := spec["paths"].(map[string]any)
		assert.Contains(t, paths, "/hello/{name}", "spec documents the example method")
	}
}

// TestInfo checks the deployment identity endpoint: id exact from the
// request URL, template present, version present and wellformed.
func TestInfo(t *testing.T) {
	base := baseURL(t)
	status, body, _ := get(t, client(), base+"/info")
	assert.Equal(t, http.StatusOK, status, "GET /info status")
	var info struct {
		ID              string `json:"id"`
		Template        string `json:"template"`
		TemplateVersion string `json:"templateVersion"`
	}
	if assert.NoError(t, json.Unmarshal([]byte(body), &info), "GET /info body is JSON") {
		assert.Equal(t, expectedID(t, base), info.ID, "GET /info id matches request URL")
		assert.NotEmpty(t, info.Template, "GET /info template present")
		assert.Regexp(t, versionRe, info.TemplateVersion, "GET /info templateVersion wellformed")
	}
}

// TestHelloFlow checks the example method end to end.
func TestHelloFlow(t *testing.T) {
	status, body, _ := get(t, client(), baseURL(t)+"/hello/world")
	assert.Equal(t, http.StatusOK, status, "GET /hello/world status")
	var greeting map[string]string
	if assert.NoError(t, json.Unmarshal([]byte(body), &greeting), "GET /hello/world body is JSON") {
		assert.Equal(t, "hello world", greeting["greeting"], "GET /hello/world body")
	}
}
