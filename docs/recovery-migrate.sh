#!/usr/bin/env bash
set -euo pipefail

# =========================================================
# Ubuntu -> NixOS migration + NixOS restore helper
# - Run as root on the target VPS
# - Prompts for all environment-specific values
# =========================================================

STATE_DIR="/root/.lumi-recovery"
STATE_FILE="$STATE_DIR/state.env"
POST_SCRIPT="$STATE_DIR/post-nixos-restore.sh"

mkdir -p "$STATE_DIR"
chmod 700 "$STATE_DIR"

log() { printf "\n[+] %s\n" "$*"; }
warn() { printf "\n[!] %s\n" "$*"; }
err() { printf "\n[x] %s\n" "$*" >&2; }

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    err "Run this script as root."
    exit 1
  fi
}

prompt_common() {
  echo "=== Recovery Setup Inputs ==="
  read -rp "Primary admin username (e.g., lumi): " ADMIN_USER
  read -rp "Server public IP or DNS (for your SSH reconnect notes): " SERVER_ENDPOINT
  read -rp "SSH public key to authorize (full ssh-ed25519 ... line): " SSH_PUBKEY
  read -rp "Private git repo URL for /etc/nixos (SSH URL): " NIXOS_REPO
  read -rp "NixOS flake host name (default: nixos): " FLAKE_HOST
  FLAKE_HOST=${FLAKE_HOST:-nixos}

  cat > "$STATE_FILE" <<EOF
ADMIN_USER=$(printf '%q' "$ADMIN_USER")
SERVER_ENDPOINT=$(printf '%q' "$SERVER_ENDPOINT")
SSH_PUBKEY=$(printf '%q' "$SSH_PUBKEY")
NIXOS_REPO=$(printf '%q' "$NIXOS_REPO")
FLAKE_HOST=$(printf '%q' "$FLAKE_HOST")
EOF
  chmod 600 "$STATE_FILE"
}

load_state() {
  if [[ -f "$STATE_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$STATE_FILE"
  else
    err "State file not found: $STATE_FILE"
    err "Run this script first on Ubuntu phase to generate state."
    exit 1
  fi
}

write_post_script() {
  cat > "$POST_SCRIPT" <<'EOS'
#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="/root/.lumi-recovery/state.env"
if [[ ! -f "$STATE_FILE" ]]; then
  echo "State file missing: $STATE_FILE" >&2
  exit 1
fi
# shellcheck source=/dev/null
source "$STATE_FILE"

echo "[+] Running NixOS post-migration restore..."

echo "[+] Ensure admin user exists and has key"
id "$ADMIN_USER" >/dev/null 2>&1 || useradd -m -G wheel "$ADMIN_USER"
mkdir -p "/home/$ADMIN_USER/.ssh"
echo "$SSH_PUBKEY" > "/home/$ADMIN_USER/.ssh/authorized_keys"
chmod 700 "/home/$ADMIN_USER/.ssh"
chmod 600 "/home/$ADMIN_USER/.ssh/authorized_keys"
chown -R "$ADMIN_USER:users" "/home/$ADMIN_USER/.ssh"

mkdir -p /root/.ssh
chmod 700 /root/.ssh
echo "$SSH_PUBKEY" > /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

# Install git if not present (usually present on NixOS base)
if ! command -v git >/dev/null 2>&1; then
  nix-shell -p git --run true
fi

if [[ ! -d /etc/nixos/.git ]]; then
  echo "[+] Cloning NixOS config repo"
  rm -rf /etc/nixos/*
  git clone "$NIXOS_REPO" /etc/nixos
else
  echo "[+] /etc/nixos is already a git repo; pulling latest"
  git -C /etc/nixos fetch --all --prune
  git -C /etc/nixos reset --hard origin/main || true
fi

if [[ -f /etc/nixos/flake.nix ]]; then
  echo "[+] Applying flake config"
  nixos-rebuild switch --flake "/etc/nixos#$FLAKE_HOST"
else
  echo "[+] Applying classic config"
  nixos-rebuild switch
fi

if id "$ADMIN_USER" >/dev/null 2>&1; then
  echo "[+] Setting password for $ADMIN_USER"
  passwd "$ADMIN_USER" || true
fi

echo "[+] Optional: set root password"
passwd root || true

echo "[+] Done. Reconnect as: ssh $ADMIN_USER@$SERVER_ENDPOINT"
EOS
  chmod 700 "$POST_SCRIPT"
}

phase_ubuntu() {
  require_root
  prompt_common
  write_post_script

  log "Installing Ubuntu prerequisites"
  apt update
  apt install -y curl git

  log "Configuring root SSH authorized_keys"
  mkdir -p /root/.ssh
  chmod 700 /root/.ssh
  echo "$SSH_PUBKEY" > /root/.ssh/authorized_keys
  chmod 600 /root/.ssh/authorized_keys

  log "Best-effort unmount of /boot/efi (known nixos-infect issue prevention)"
  umount /boot/efi 2>/dev/null || umount -l /boot/efi 2>/dev/null || true

  log "Downloading nixos-infect"
  curl -fsSL https://raw.githubusercontent.com/elitak/nixos-infect/master/nixos-infect -o /root/nixos-infect
  chmod +x /root/nixos-infect

  log "Applying bootFs fallback patch for legacy/BIOS compatibility"
  sed -i '/rm -rf \$bootFs\.bak/i : "${bootFs:=/boot}"' /root/nixos-infect

  warn "About to replace Ubuntu with NixOS (destructive)."
  read -rp "Type YES to continue: " CONFIRM
  if [[ "$CONFIRM" != "YES" ]]; then
    err "Aborted."
    exit 1
  fi

  log "Starting nixos-infect (system will reboot automatically)"
  doNetConf=y NIX_CHANNEL=nixos-25.11 bash -x /root/nixos-infect
}

phase_nixos() {
  require_root
  load_state
  log "Detected NixOS, running restore phase"
  bash "$POST_SCRIPT"
}

detect_phase() {
  if [[ -f /etc/os-release ]]; then
    # shellcheck source=/dev/null
    source /etc/os-release
    case "${ID:-}" in
      ubuntu|debian)
        phase_ubuntu
        ;;
      nixos)
        phase_nixos
        ;;
      *)
        err "Unsupported OS ID: ${ID:-unknown}. Run manually."
        exit 1
        ;;
    esac
  else
    err "/etc/os-release not found."
    exit 1
  fi
}

detect_phase
