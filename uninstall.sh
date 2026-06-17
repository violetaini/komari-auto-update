#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root." >&2
  exit 1
fi

systemctl disable --now komari-auto-update.timer >/dev/null 2>&1 || true
rm -f /etc/systemd/system/komari-auto-update.service
rm -f /etc/systemd/system/komari-auto-update.timer
rm -f /usr/local/sbin/komari-auto-update
rm -f /usr/local/sbin/komari-auto-update-uninstall
rm -f /etc/komari-auto-update.conf
systemctl daemon-reload >/dev/null 2>&1 || true

echo "komari-auto-update uninstalled."
