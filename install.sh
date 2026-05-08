#!/usr/bin/env bash
# HydraaLabs DNS - Linux + macOS installer
# Sets dns.hydrabrowser.net (45.8.125.44, 185.125.168.124) as system resolver,
# with DNS-over-TLS by default.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/HydraaLabs/dns-installer/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/HydraaLabs/dns-installer/main/install.sh | bash -s -- --plain
#   curl -fsSL https://raw.githubusercontent.com/HydraaLabs/dns-installer/main/install.sh | bash -s -- --uninstall
#
# Flags:
#   --plain       Use clear DNS (port 53) instead of DoT (port 853)
#   --uninstall   Remove HydraaLabs DNS config and restore previous settings
#   --yes         Skip confirmation prompt

# Auto re-exec under bash if invoked via sh (dash etc.)
if [ -z "${BASH_VERSION:-}" ]; then
  exec bash -c "$(curl -fsSL https://raw.githubusercontent.com/HydraaLabs/dns-installer/main/install.sh)" -- "$@"
fi

set -euo pipefail

# ----- Constants -------------------------------------------------------------
HOSTNAME="dns.hydrabrowser.net"
IPV4_SERVERS=("45.8.125.44" "185.125.168.124")
TAG="hydrabrowser-dns"  # marker so we can find/remove our config

# ----- Args ------------------------------------------------------------------
MODE="dot"        # dot | plain
ACTION="install"  # install | uninstall
ASSUME_YES=0
for arg in "$@"; do
  case "$arg" in
    --plain)     MODE="plain" ;;
    --dot)       MODE="dot" ;;
    --uninstall) ACTION="uninstall" ;;
    --yes|-y)    ASSUME_YES=1 ;;
    -h|--help)
      cat <<'HELP'
HydraaLabs DNS - Linux + macOS installer
Sets dns.hydrabrowser.net (45.8.125.44, 185.125.168.124) as system resolver,
with DNS-over-TLS by default.

Usage:
  curl -fsSL https://raw.githubusercontent.com/HydraaLabs/dns-installer/main/install.sh | bash
  curl -fsSL https://raw.githubusercontent.com/HydraaLabs/dns-installer/main/install.sh | bash -s -- --plain
  curl -fsSL https://raw.githubusercontent.com/HydraaLabs/dns-installer/main/install.sh | bash -s -- --uninstall

Flags:
  --plain       Use clear DNS (port 53) instead of DoT (port 853)
  --uninstall   Remove HydraaLabs DNS config and restore previous settings
  --yes         Skip confirmation prompt
HELP
      exit 0 ;;
    *) echo "Unknown flag: $arg" >&2; exit 2 ;;
  esac
done

# ----- Helpers ---------------------------------------------------------------
have() { command -v "$1" >/dev/null 2>&1; }
log() { printf "\033[1;36m==>\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m!!  %s\033[0m\n" "$*" >&2; }
die() { printf "\033[1;31m!!  %s\033[0m\n" "$*" >&2; exit 1; }

# ANSI colors as variables so they can be expanded inside heredocs.
CYAN="$(printf '\033[1;36m')"
YELLOW="$(printf '\033[1;33m')"
BOLD="$(printf '\033[1m')"
RESET="$(printf '\033[0m')"

require_sudo() {
  if [ "$(id -u)" -ne 0 ]; then
    if have sudo; then SUDO="sudo"; else die "Need root or sudo"; fi
  else
    SUDO=""
  fi
}

# Confirm: auto-yes when piped (no TTY) or when --yes given.
# Reads from /dev/tty if available so local users still get the prompt.
confirm() {
  [ "$ASSUME_YES" -eq 1 ] && return 0
  if [ -r /dev/tty ] && [ -t 1 ]; then
    printf "\n%s [Y/n] " "$1" >/dev/tty
    read -r ans </dev/tty
    case "$ans" in [nN]|[nN][oO]) return 1 ;; *) return 0 ;; esac
  fi
  # Piped install (curl | bash) — proceed by default
  return 0
}

# ----- OS detection ----------------------------------------------------------
OS="$(uname -s)"
case "$OS" in
  Linux)  PLATFORM="linux" ;;
  Darwin) PLATFORM="macos" ;;
  *)      die "Unsupported OS: $OS (Linux/macOS only). For Windows use install.ps1." ;;
esac

# =============================================================================
# LINUX
# =============================================================================
linux_detect_resolver() {
  if have systemctl && systemctl is-active --quiet systemd-resolved; then
    if have nmcli && systemctl is-active --quiet NetworkManager 2>/dev/null; then
      echo "networkmanager+resolved"
    else
      echo "systemd-resolved"
    fi
  elif have nmcli && systemctl is-active --quiet NetworkManager 2>/dev/null; then
    echo "networkmanager"
  elif have resolvconf; then
    echo "resolvconf"
  else
    echo "resolvconf-static"
  fi
}

linux_install() {
  local resolver="$1"
  log "Detected resolver: $resolver"

  case "$resolver" in
    "systemd-resolved" | "networkmanager+resolved")
      $SUDO mkdir -p /etc/systemd/resolved.conf.d
      $SUDO tee "/etc/systemd/resolved.conf.d/${TAG}.conf" >/dev/null <<EOF
# Managed by hydrabrowser dns-installer (do not edit, run install.sh --uninstall to remove)
[Resolve]
DNS=${IPV4_SERVERS[0]}#${HOSTNAME} ${IPV4_SERVERS[1]}#${HOSTNAME}
$( [ "$MODE" = "dot" ] && echo "DNSOverTLS=yes" || echo "DNSOverTLS=no" )
DNSSEC=allow-downgrade
Domains=~.
EOF
      $SUDO systemctl restart systemd-resolved
      log "systemd-resolved configured (mode=$MODE, DNSOverTLS=$([ "$MODE" = "dot" ] && echo yes || echo no))"
      ;;
    "networkmanager")
      local conn dev
      conn="$(nmcli -t -f NAME,DEVICE c show --active | grep -v '^lo:\|^docker\|^br-\|tailscale\|wireguard' | head -1 | cut -d: -f1)"
      dev="$(nmcli -t -f NAME,DEVICE c show --active | grep -v '^lo:\|^docker\|^br-\|tailscale\|wireguard' | head -1 | cut -d: -f2)"
      [ -z "$conn" ] && die "No active network connection found"
      log "Active connection: $conn ($dev)"
      $SUDO nmcli con mod "$conn" ipv4.dns "${IPV4_SERVERS[0]} ${IPV4_SERVERS[1]}" ipv4.ignore-auto-dns yes
      if [ "$MODE" = "dot" ]; then
        $SUDO nmcli con mod "$conn" connection.dns-over-tls yes 2>/dev/null \
          || warn "NM version does not support dns-over-tls. Install will use plain DNS."
      fi
      $SUDO nmcli dev reapply "$dev"
      log "NetworkManager connection $conn updated"
      ;;
    "resolvconf" | "resolvconf-static")
      # Direct /etc/resolv.conf (no DoT support without extra software)
      [ "$MODE" = "dot" ] && warn "resolvconf-only setup: DoT not supported, falling back to plain DNS"
      $SUDO cp /etc/resolv.conf "/etc/resolv.conf.${TAG}.backup" 2>/dev/null || true
      $SUDO tee /etc/resolv.conf >/dev/null <<EOF
# Managed by hydrabrowser dns-installer
nameserver ${IPV4_SERVERS[0]}
nameserver ${IPV4_SERVERS[1]}
options edns0
EOF
      ;;
  esac
}

linux_uninstall() {
  local resolver="$1"
  case "$resolver" in
    "systemd-resolved" | "networkmanager+resolved")
      $SUDO rm -f "/etc/systemd/resolved.conf.d/${TAG}.conf"
      $SUDO systemctl restart systemd-resolved
      log "Removed /etc/systemd/resolved.conf.d/${TAG}.conf"
      ;;
    "networkmanager")
      local conn dev
      conn="$(nmcli -t -f NAME,DEVICE c show --active | grep -v '^lo:\|^docker\|^br-\|tailscale\|wireguard' | head -1 | cut -d: -f1)"
      dev="$(nmcli -t -f NAME,DEVICE c show --active | grep -v '^lo:\|^docker\|^br-\|tailscale\|wireguard' | head -1 | cut -d: -f2)"
      [ -z "$conn" ] && die "No active connection to revert"
      $SUDO nmcli con mod "$conn" ipv4.dns "" ipv4.ignore-auto-dns no
      $SUDO nmcli con mod "$conn" connection.dns-over-tls -1 2>/dev/null || true
      $SUDO nmcli dev reapply "$dev"
      log "Reverted NM connection $conn to defaults"
      ;;
    "resolvconf" | "resolvconf-static")
      if [ -f "/etc/resolv.conf.${TAG}.backup" ]; then
        $SUDO mv "/etc/resolv.conf.${TAG}.backup" /etc/resolv.conf
        log "Restored /etc/resolv.conf from backup"
      else
        warn "No backup found at /etc/resolv.conf.${TAG}.backup"
      fi
      ;;
  esac
}

# =============================================================================
# macOS
# =============================================================================
macos_install() {
  local services
  services="$(networksetup -listallnetworkservices | tail -n +2)"
  [ -z "$services" ] && die "No network services found"

  while IFS= read -r svc; do
    [ -z "$svc" ] && continue
    case "$svc" in *"\\*"*) continue ;; esac
    log "Configuring $svc"
    $SUDO networksetup -setdnsservers "$svc" "${IPV4_SERVERS[0]}" "${IPV4_SERVERS[1]}"
  done <<< "$services"

  if [ "$MODE" = "dot" ]; then
    cat <<EOF

${YELLOW}Note (macOS):${RESET} DoT/DoH at OS level requires installing a configuration
profile. Get and double-click hydrabrowser-dns.mobileconfig:
  curl -fsSL https://raw.githubusercontent.com/HydraaLabs/dns-installer/main/ios/hydrabrowser-dns.mobileconfig -o ~/Downloads/hydrabrowser-dns.mobileconfig
  open ~/Downloads/hydrabrowser-dns.mobileconfig

Then approve the profile in System Settings > Privacy & Security > Profiles.
EOF
  fi
  log "macOS DNS set on all services. Plain DNS active. Profile required for DoT."
}

macos_uninstall() {
  local services
  services="$(networksetup -listallnetworkservices | tail -n +2)"
  while IFS= read -r svc; do
    [ -z "$svc" ] && continue
    case "$svc" in *"\\*"*) continue ;; esac
    $SUDO networksetup -setdnsservers "$svc" "Empty" 2>/dev/null || true
  done <<< "$services"
  log "macOS DNS reverted to DHCP defaults"
  warn "If you installed the .mobileconfig profile, remove it manually in System Settings > Profiles"
}

# =============================================================================
# MAIN
# =============================================================================
require_sudo

cat <<EOF

${CYAN}HydraaLabs DNS installer${RESET}
  Hostname : $HOSTNAME
  Servers  : ${IPV4_SERVERS[0]}, ${IPV4_SERVERS[1]}
  Mode     : $([ "$MODE" = "dot" ] && echo "DNS-over-TLS (encrypted)" || echo "Plain DNS")
  Action   : $ACTION
  Platform : $PLATFORM
EOF

if [ "$ACTION" = "install" ]; then
  confirm "Continue?" || { log "Aborted"; exit 0; }
fi

if [ "$PLATFORM" = "linux" ]; then
  RESOLVER="$(linux_detect_resolver)"
  if [ "$ACTION" = "install" ]; then linux_install "$RESOLVER"; else linux_uninstall "$RESOLVER"; fi
else
  if [ "$ACTION" = "install" ]; then macos_install; else macos_uninstall; fi
fi

if [ "$ACTION" = "install" ]; then
  log "Done. Test with: dig +short example.com"
  printf "Rollback: %scurl -fsSL https://raw.githubusercontent.com/HydraaLabs/dns-installer/main/install.sh | bash -s -- --uninstall%s\n" "$BOLD" "$RESET"
else
  log "Uninstall complete"
fi
