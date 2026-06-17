#!/usr/bin/env bash
set -Eeuo pipefail

REPO_RAW_BASE="${REPO_RAW_BASE:-https://raw.githubusercontent.com/violetaini/komari-auto-update/main}"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/sbin}"
CONFIG_FILE="${CONFIG_FILE:-/etc/komari-auto-update.conf}"
SERVICE_FILE="/etc/systemd/system/komari-auto-update.service"
TIMER_FILE="/etc/systemd/system/komari-auto-update.timer"

KOMARI_BIN="${KOMARI_BIN:-/opt/komari/komari}"
KOMARI_SERVICE="${KOMARI_SERVICE:-komari.service}"
KOMARI_API="${KOMARI_API:-http://127.0.0.1:25774/api/version}"
INTERVAL="${INTERVAL:-6h}"
KEEP_BACKUPS="${KEEP_BACKUPS:-2}"
RUN_NOW=1

usage() {
  cat <<'EOF'
Usage: bash install.sh [options]

Options:
  --interval VALUE       systemd interval, for example 6h, 12h, 1d (default: 6h)
  --keep-backups N       keep the latest N binary backups and N data backups (default: 2)
  --bin PATH             Komari binary path (default: /opt/komari/komari)
  --service NAME         Komari systemd service name (default: komari.service)
  --api URL              local Komari version API (default: http://127.0.0.1:25774/api/version)
  --no-run-now           install only; do not run the first update check immediately
  -h, --help             show this help

Environment variables with the same names can also be used:
  INTERVAL=12h KEEP_BACKUPS=3 bash install.sh
EOF
}

log() {
  printf '\033[1;32m[komari-auto-update]\033[0m %s\n' "$*"
}

warn() {
  printf '\033[1;33m[komari-auto-update]\033[0m %s\n' "$*" >&2
}

die() {
  printf '\033[1;31m[komari-auto-update]\033[0m ERROR: %s\n' "$*" >&2
  exit 1
}

require_root() {
  [[ "${EUID}" -eq 0 ]] || die "Please run as root."
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

validate_positive_int() {
  [[ "$1" =~ ^[1-9][0-9]*$ ]]
}

validate_systemd_interval() {
  [[ "$1" =~ ^[1-9][0-9]*(s|sec|second|seconds|min|minute|minutes|h|hr|hour|hours|d|day|days|w|week|weeks|m|month|months|y|year|years)$ ]]
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --interval)
        INTERVAL="${2:-}"
        shift 2
        ;;
      --keep-backups)
        KEEP_BACKUPS="${2:-}"
        shift 2
        ;;
      --bin)
        KOMARI_BIN="${2:-}"
        shift 2
        ;;
      --service)
        KOMARI_SERVICE="${2:-}"
        shift 2
        ;;
      --api)
        KOMARI_API="${2:-}"
        shift 2
        ;;
      --no-run-now)
        RUN_NOW=0
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Unknown argument: $1"
        ;;
    esac
  done
}

detect_komari_binary_install() {
  [[ -x "$KOMARI_BIN" ]] || die "Komari binary not found or not executable: $KOMARI_BIN"
  if command -v systemctl >/dev/null 2>&1; then
    systemctl list-unit-files "$KOMARI_SERVICE" --no-pager >/dev/null 2>&1 || true
    systemctl cat "$KOMARI_SERVICE" >/dev/null 2>&1 || die "Komari systemd service not found: $KOMARI_SERVICE"
    local exec_start
    exec_start="$(systemctl show "$KOMARI_SERVICE" -p ExecStart --value 2>/dev/null || true)"
    [[ "$exec_start" == *"$KOMARI_BIN"* ]] || die "This installer only supports binary Komari installs where ${KOMARI_SERVICE} runs ${KOMARI_BIN}."
  else
    die "systemd is required. This project only supports systemd-managed binary Komari installs."
  fi
}

install_updater_binary() {
  local target="${INSTALL_DIR}/komari-auto-update"
  mkdir -p "$INSTALL_DIR"

  if [[ -f "./komari-auto-update" ]]; then
    install -m 0755 "./komari-auto-update" "$target"
  else
    require_cmd curl
    curl -fsSL -o "$target" "${REPO_RAW_BASE}/komari-auto-update"
    chmod 0755 "$target"
  fi

  bash -n "$target"
}

write_config() {
  cat > "$CONFIG_FILE" <<EOF
# Managed by komari-auto-update installer.
KOMARI_BIN="${KOMARI_BIN}"
KOMARI_SERVICE="${KOMARI_SERVICE}"
KOMARI_API="${KOMARI_API}"
KEEP_BACKUPS="${KEEP_BACKUPS}"
EOF
  chmod 0644 "$CONFIG_FILE"
}

write_units() {
  cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Check and update Komari Monitor server binary
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=${INSTALL_DIR}/komari-auto-update
Nice=10
IOSchedulingClass=best-effort
IOSchedulingPriority=7
EOF

  cat > "$TIMER_FILE" <<EOF
[Unit]
Description=Komari Monitor server auto-update check every ${INTERVAL}

[Timer]
OnBootSec=10m
OnUnitActiveSec=${INTERVAL}
RandomizedDelaySec=10m
AccuracySec=1m
Persistent=true
Unit=komari-auto-update.service

[Install]
WantedBy=timers.target
EOF
}

install_uninstaller() {
  cat > "${INSTALL_DIR}/komari-auto-update-uninstall" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

systemctl disable --now komari-auto-update.timer >/dev/null 2>&1 || true
rm -f /etc/systemd/system/komari-auto-update.service
rm -f /etc/systemd/system/komari-auto-update.timer
rm -f /usr/local/sbin/komari-auto-update
rm -f /usr/local/sbin/komari-auto-update-uninstall
rm -f /etc/komari-auto-update.conf
systemctl daemon-reload >/dev/null 2>&1 || true
echo "komari-auto-update uninstalled."
EOF
  chmod 0755 "${INSTALL_DIR}/komari-auto-update-uninstall"
}

main() {
  parse_args "$@"
  require_root
  require_cmd bash
  require_cmd install
  require_cmd systemctl
  require_cmd jq
  require_cmd flock
  require_cmd tar
  require_cmd timeout
  require_cmd cmp

  validate_positive_int "$KEEP_BACKUPS" || die "--keep-backups must be a positive integer."
  validate_systemd_interval "$INTERVAL" || die "--interval must be a simple systemd interval such as 6h, 12h, or 1d."

  detect_komari_binary_install
  install_updater_binary
  write_config
  write_units
  install_uninstaller

  systemctl daemon-reload
  systemd-analyze verify "$SERVICE_FILE" "$TIMER_FILE"
  systemctl enable --now komari-auto-update.timer

  log "Installed."
  log "Timer interval: ${INTERVAL}"
  log "Backup retention: ${KEEP_BACKUPS}"
  log "Config: ${CONFIG_FILE}"
  log "Manual check: ${INSTALL_DIR}/komari-auto-update"
  log "Uninstall: ${INSTALL_DIR}/komari-auto-update-uninstall"

  if [[ "$RUN_NOW" -eq 1 ]]; then
    log "Running one update check now."
    systemctl start komari-auto-update.service
  fi

  systemctl list-timers --all --no-pager | grep -E 'komari-auto-update|NEXT' || true
}

main "$@"
