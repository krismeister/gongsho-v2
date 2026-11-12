# lib/paths.sh — absolute path builders (pass validated IDs/paths/sessions).
# Sourced via tools/lib.sh; never sourced or run alone.

app_dir() { printf '%s/apps/%s' "$REPO_ROOT" "$(id_to_path "$1")"; }          # <id>
bin_dir() { printf '%s/bin/%s' "$REPO_ROOT" "$(id_to_path "$1")"; }           # <id>
data_dir() { printf '%s/data/%s' "$REPO_ROOT" "$(id_to_path "$1")"; }         # <id>
proxy_file() { printf '%s/proxy/deployments/%s' "$REPO_ROOT" "$1"; }          # <id>
socket_path() { printf '%s/proxy/sockets/%s.sock' "$REPO_ROOT" "$1"; }        # <id>
pidfile_path() { printf '%s/proxy/sockets/%s.pid' "$REPO_ROOT" "$1"; }        # <id>
log_path() { printf '%s/proxy/sockets/%s.log' "$REPO_ROOT" "$1"; }            # <id>
dev_proxy_file() { printf '%s/proxy/dev.d/%s-%s' "$REPO_ROOT" "$1" "$2"; }    # <session> <id>
dev_socket_path() { printf '%s/proxy/sockets/%s.dev-%s.sock' "$REPO_ROOT" "$2" "$1"; } # <session> <id>
dev_pidfile_path() { printf '%s/proxy/sockets/%s.dev-%s.pid' "$REPO_ROOT" "$2" "$1"; } # <session> <id>
dev_log_path() { printf '%s/proxy/sockets/%s.dev-%s.log' "$REPO_ROOT" "$2" "$1"; }     # <session> <id>
run_session_dir() { printf '%s/run/%s' "$REPO_ROOT" "$1"; }                   # <session>
artifacts_dir() { printf '%s/run/%s/artifacts' "$REPO_ROOT" "$1"; }           # <session>
dev_bundle_dir() { printf '%s/run/%s/bundles/%s' "$REPO_ROOT" "$1" "$(id_to_path "$2")"; } # <session> <id>
dev_db_path() { printf '%s/run/%s/data/%s/app.db' "$REPO_ROOT" "$1" "$(id_to_path "$2")"; } # <session> <id>
template_dir() { printf '%s/templates/%s' "$REPO_ROOT" "$1"; }                # <template>
stanza_src() { printf '%s/templates/%s/config/caddy/stanza' "$REPO_ROOT" "$1"; } # <template>
health_spec() { printf '%s/templates/%s/config/health.json' "$REPO_ROOT" "$1"; } # <template>
