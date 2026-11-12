// Command api serves one gongsho API deployment: it reads its config from the
// environment (injected by start), opens the deployment's SQLite database,
// and serves the Goa HTTP server on the deployment's unix socket.
package main

import (
	"context"
	"database/sql"
	_ "embed" // Blank: this toolchain reports a plain embed import as unused; the directive still embeds.
	"encoding/json"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	goahttp "goa.design/goa/v3/http"
	_ "modernc.org/sqlite"

	"gongsho/template/goa-api/gen/greet"
	greetsvr "gongsho/template/goa-api/gen/http/greet/server"
	"gongsho/template/goa-api/service"
)

// openAPISpec is the normalized OpenAPI document served at GET /openapi.json.
// The build copies gen/http/openapi3.json to gen/openapi.json after `goa gen`.
//
//go:embed gen/openapi.json
var openAPISpec []byte

// Runtime config keys. SOCKET_PATH, DB_PATH, DEPLOYMENT_ID, TEMPLATE, and
// TEMPLATE_VERSION are injected by start (pin-derived, per instance);
// LOG_LEVEL is the settable tunable (see .example.env).
const (
	envSocket   = "SOCKET_PATH"
	envDB       = "DB_PATH"
	envLogLevel = "LOG_LEVEL"
)

const (
	defaultLogLevel = "info"
	// shutdownTimeout caps graceful shutdown inside the supervisor's 5s
	// SIGTERM grace (see docs/phase-1/supervision-and-runtime.md).
	shutdownTimeout = 4 * time.Second
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintf(os.Stderr, "api: %v\n", err)
		os.Exit(1)
	}
}

func run() error {
	socket, err := requireEnv(envSocket)
	if err != nil {
		return err
	}
	dbPath, err := requireEnv(envDB)
	if err != nil {
		return err
	}
	if err := service.CheckDeploymentEnv(); err != nil {
		return err
	}
	logger, err := newLogger(envOr(envLogLevel, defaultLogLevel))
	if err != nil {
		return err
	}
	info := service.DeploymentInfo()
	infoBody, err := json.Marshal(info)
	if err != nil {
		return fmt.Errorf("encode /info: %w", err)
	}

	if _, err := os.Stat(dbPath); err != nil {
		return fmt.Errorf("database %q: %v (create it with the migrate step first)", dbPath, err)
	}
	db, err := sql.Open("sqlite", dbPath)
	if err != nil {
		return fmt.Errorf("open database: %w", err)
	}
	defer db.Close()
	if err := checkSchema(db); err != nil {
		return fmt.Errorf("database %q failed schema check: %w (apply migrations first)", dbPath, err)
	}

	mux := goahttp.NewMuxer()
	endpoints := greet.NewEndpoints(service.NewGreet(db))
	svr := greetsvr.New(endpoints, mux, goahttp.RequestDecoder, goahttp.ResponseEncoder, errorHandler(logger), nil)
	greetsvr.Mount(mux, svr)
	mux.Handle("GET", "/healthz", serveBytes("application/json", []byte(`{"status":"ok"}`)))
	mux.Handle("GET", "/openapi.json", serveBytes("application/json", openAPISpec))
	mux.Handle("GET", "/info", serveBytes("application/json", infoBody))

	if err := os.MkdirAll(filepath.Dir(socket), 0o755); err != nil {
		return fmt.Errorf("create socket dir: %w", err)
	}
	_ = os.Remove(socket) // Unlink a stale socket from a previous run.
	listener, err := net.Listen("unix", socket)
	if err != nil {
		return fmt.Errorf("listen on %s: %w", socket, err)
	}
	httpSrv := &http.Server{Handler: mux, ReadHeaderTimeout: 60 * time.Second}

	for _, m := range svr.Mounts {
		logger.Info("mounted", "method", m.Method, "verb", m.Verb, "pattern", m.Pattern)
	}
	logger.Info("listening", "socket", socket, "id", info.ID)

	errc := make(chan error, 1)
	go func() { errc <- httpSrv.Serve(listener) }()

	sigc := make(chan os.Signal, 1)
	signal.Notify(sigc, syscall.SIGINT, syscall.SIGTERM)
	select {
	case sig := <-sigc:
		logger.Info("shutting down", "signal", sig.String())
	case err := <-errc:
		return fmt.Errorf("serve: %w", err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), shutdownTimeout)
	defer cancel()
	if err := httpSrv.Shutdown(ctx); err != nil {
		return fmt.Errorf("shutdown: %w", err)
	}
	logger.Info("exited")
	return nil
}

// checkSchema verifies the example schema exists without changing anything.
// Migrations always run as an explicit step, never here.
func checkSchema(db *sql.DB) error {
	var value string
	return db.QueryRow("SELECT value FROM app_constants WHERE key = ?", "greeting").Scan(&value)
}

func serveBytes(contentType string, body []byte) http.HandlerFunc {
	return func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", contentType)
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write(body)
	}
}

func errorHandler(logger *slog.Logger) func(context.Context, http.ResponseWriter, error) {
	return func(_ context.Context, _ http.ResponseWriter, err error) {
		logger.Error("request error", "err", err)
	}
}

// requireEnv returns a required variable or a clear error naming who sets it.
func requireEnv(key string) (string, error) {
	if value, ok := os.LookupEnv(key); ok && value != "" {
		return value, nil
	}
	return "", fmt.Errorf("missing required %s (injected by start)", key)
}

func envOr(key, fallback string) string {
	if value, ok := os.LookupEnv(key); ok && value != "" {
		return value
	}
	return fallback
}

func newLogger(level string) (*slog.Logger, error) {
	var l slog.Level
	switch strings.ToLower(level) {
	case "debug":
		l = slog.LevelDebug
	case "info":
		l = slog.LevelInfo
	case "warn", "warning":
		l = slog.LevelWarn
	case "error":
		l = slog.LevelError
	default:
		return nil, fmt.Errorf("invalid %s %q: want debug, info, warn, or error", envLogLevel, level)
	}
	return slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{Level: l})), nil
}
