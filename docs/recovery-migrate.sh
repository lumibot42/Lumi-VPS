#!/usr/bin/env bash
set -euo pipefail

# Ubuntu -> NixOS migration + NixOS restore helper
# Run as root. Prompts for host-specific values.

STATE_DIR="/root/.lumi-recovery"
STATE_FILE="$STATE_DIR/state.env"
POST_SCRIPT="$STATE_DIR/post-nixos-restore.sh"
mkdir -p "$STATE_DIR" && chmod 700 "$STATE_DIR"

log() { printf "\n[+] %s\n" "$*"; }
warn() { printf "\n[!] %s\n" "$*"; }
err() { printf "\n[x] %s\n" "$*" >&2; }

require_root() {
  [[ "${EUID:-$(id -u)}" -eq 0 ]] || { err "Run as root."; exit 1; }
}

prompt_common() {
  echo "=== Recovery Inputs ==="
  read -rp "Admin username (e.g., lumi): " ADMIN_USER
  read -rp "Server public IP or DNS: " SERVER_ENDPOINT
  read -rp "SSH public key (full line): " SSH_PUBKEY
  read -rp "NixOS repo URL (SSH or HTTPS): " NIXOS_REPO
  read -rp "Flake host (default: nixos): " FLAKE_HOST
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

load_or_prompt_state() {
  if [[ -f "$STATE_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$STATE_FILE"
  else
    warn "State file missing (common after nixos-infect). Re-entering inputs."
    prompt_common
  fi
}

ensure_repo_auth() {
  if [[ "$NIXOS_REPO" =~ ^git@ ]]; then
    mkdir -p /root/.ssh && chmod 700 /root/.ssh
    if [[ ! -f /root/.ssh/id_ed25519 ]]; then
      warn "No /root/.ssh/id_ed25519 found for SSH clone."
      read -rp "Generate a new SSH key now? [Y/n]: " GEN
      if [[ -z "${GEN:-}" || "${GEN,,}" == "y" || "${GEN,,}" == "yes" ]]; then
        ssh-keygen -t ed25519 -N '' -f /root/.ssh/id_ed25519 -C "recovery@$(hostname)" >/dev/null
        echo
        echo "Add this deploy key to GitHub, then press Enter:"
        cat /root/.ssh/id_ed25519.pub
        read -r
      else
        err "SSH key required for git@ repo URL."
        exit 1
      fi
    fi
    ssh-keyscan -H github.com >> /root/.ssh/known_hosts 2>/dev/null || true
    chmod 600 /root/.ssh/known_hosts || true
    if ! GIT_SSH_COMMAND='ssh -o StrictHostKeyChecking=accept-new' git ls-remote "$NIXOS_REPO" >/dev/null 2>&1; then
      err "SSH access to repo failed: $NIXOS_REPO"
      exit 1
    fi
  else
    if [[ "$NIXOS_REPO" =~ ^https:// ]]; then
      log "Using HTTPS repo URL"
      if ! git ls-remote "$NIXOS_REPO" >/dev/null 2>&1; then
        warn "HTTPS repo auth required."
        read -rp "GitHub username: " GH_USER
        read -rsp "GitHub token (classic/PAT with repo read): " GH_TOKEN
        echo
        export NIXOS_REPO_AUTH="https://${GH_USER}:${GH_TOKEN}@${NIXOS_REPO#https://}"
      fi
    else
      err "Unsupported repo URL. Use SSH (git@...) or HTTPS (https://...)."
      exit 1
    fi
  fi
}

repo_url_effective() {
  if [[ -n "${NIXOS_REPO_AUTH:-}" ]]; then
    printf '%s' "$NIXOS_REPO_AUTH"
  else
    printf '%s' "$NIXOS_REPO"
  fi
}

write_post_script() {
  cat > "$POST_SCRIPT" <<'EOS'
#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="/root/.lumi-recovery"
STATE_FILE="$STATE_DIR/state.env"

log() { printf "\n[+] %s\n" "$*"; }
warn() { printf "\n[!] %s\n" "$*"; }
err() { printf "\n[x] %s\n" "$*" >&2; }

prompt_common() {
  echo "=== Recovery Inputs (NixOS phase) ==="
  read -rp "Admin username (e.g., lumi): " ADMIN_USER
  read -rp "Server public IP or DNS: " SERVER_ENDPOINT
  read -rp "SSH public key (full line): " SSH_PUBKEY
  read -rp "NixOS repo URL (SSH or HTTPS): " NIXOS_REPO
  read -rp "Flake host (default: nixos): " FLAKE_HOST
  FLAKE_HOST=${FLAKE_HOST:-nixos}

  mkdir -p "$STATE_DIR" && chmod 700 "$STATE_DIR"
  cat > "$STATE_FILE" <<EOF
ADMIN_USER=$(printf '%q' "$ADMIN_USER")
SERVER_ENDPOINT=$(printf '%q' "$SERVER_ENDPOINT")
SSH_PUBKEY=$(printf '%q' "$SSH_PUBKEY")
NIXOS_REPO=$(printf '%q' "$NIXOS_REPO")
FLAKE_HOST=$(printf '%q' "$FLAKE_HOST")
EOF
  chmod 600 "$STATE_FILE"
}

load_or_prompt_state() {
  if [[ -f "$STATE_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$STATE_FILE"
  else
    warn "State file missing. Re-entering inputs."
    prompt_common
  fi
}

ensure_repo_auth() {
  if [[ "$NIXOS_REPO" =~ ^git@ ]]; then
    mkdir -p /root/.ssh && chmod 700 /root/.ssh
    if [[ ! -f /root/.ssh/id_ed25519 ]]; then
      warn "No /root/.ssh/id_ed25519 found for SSH clone."
      read -rp "Generate a new SSH key now? [Y/n]: " GEN
      if [[ -z "${GEN:-}" || "${GEN,,}" == "y" || "${GEN,,}" == "yes" ]]; then
        ssh-keygen -t ed25519 -N '' -f /root/.ssh/id_ed25519 -C "recovery@$(hostname)" >/dev/null
        echo
        echo "Add this deploy key to GitHub, then press Enter:"
        cat /root/.ssh/id_ed25519.pub
        read -r
      else
        err "SSH key required for git@ repo URL."
        exit 1
      fi
    fi
    ssh-keyscan -H github.com >> /root/.ssh/known_hosts 2>/dev/null || true
    chmod 600 /root/.ssh/known_hosts || true
    GIT_CLONE_URL="$NIXOS_REPO"
  elif [[ "$NIXOS_REPO" =~ ^https:// ]]; then
    GIT_CLONE_URL="$NIXOS_REPO"
    if ! git ls-remote "$NIXOS_REPO" >/dev/null 2>&1; then
      warn "HTTPS repo auth required."
      read -rp "GitHub username: " GH_USER
      read -rsp "GitHub token (classic/PAT with repo read): " GH_TOKEN
      echo
      GIT_CLONE_URL="https://${GH_USER}:${GH_TOKEN}@${NIXOS_REPO#https://}"
    fi
  else
    err "Unsupported repo URL."
    exit 1
  fi
}

load_or_prompt_state
ensure_repo_auth

log "Running NixOS post-migration restore"

id "$ADMIN_USER" >/dev/null 2>&1 || useradd -m -G wheel "$ADMIN_USER"
mkdir -p "/home/$ADMIN_USER/.ssh"
echo "$SSH_PUBKEY" > "/home/$ADMIN_USER/.ssh/authorized_keys"
chmod 700 "/home/$ADMIN_USER/.ssh"
chmod 600 "/home/$ADMIN_USER/.ssh/authorized_keys"
chown -R "$ADMIN_USER:users" "/home/$ADMIN_USER/.ssh"

mkdir -p /root/.ssh && chmod 700 /root/.ssh
echo "$SSH_PUBKEY" > /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

if ! command -v git >/dev/null 2>&1; then
  nix-shell -p git --run true
fi

if [[ -d /etc/nixos/.git ]]; then
  log "Updating existing /etc/nixos"
  git -C /etc/nixos fetch --all --prune
  git -C /etc/nixos reset --hard origin/main || true
else
  log "Cloning /etc/nixos from repo"
  rm -rf /etc/nixos/*
  git clone "$GIT_CLONE_URL" /etc/nixos
fi

if [[ -f /etc/nixos/flake.nix ]]; then
  nixos-rebuild switch --flake "/etc/nixos#$FLAKE_HOST"
else
  nixos-rebuild switch
fi

if id "$ADMIN_USER" >/dev/null 2>&1; then
  read -rp "Set password for $ADMIN_USER now? [Y/n]: " SET_USER_PW
  if [[ -z "${SET_USER_PW:-}" || "${SET_USER_PW,,}" == "y" || "${SET_USER_PW,,}" == "yes" ]]; then
    passwd "$ADMIN_USER"
  else
    warn "Skipped $ADMIN_USER password."
  fi
fi

read -rp "Set root password now? [y/N]: " SET_ROOT_PW
if [[ "${SET_ROOT_PW,,}" == "y" || "${SET_ROOT_PW,,}" == "yes" ]]; then
  passwd root
else
  warn "Skipped root password."
fi

log "Done. Reconnect as: ssh $ADMIN_USER@$SERVER_ENDPOINT"
EOS
  chmod 700 "$POST_SCRIPT"
}

phase_ubuntu() {
  require_root
  prompt_common
  ensure_repo_auth
  write_post_script

  log "Installing Ubuntu prerequisites"
  apt update
  apt install -y curl git

  log "Configuring root SSH key"
  mkdir -p /root/.ssh && chmod 700 /root/.ssh
  echo "$SSH_PUBKEY" > /root/.ssh/authorized_keys
  chmod 600 /root/.ssh/authorized_keys

  log "Best-effort unmount of /boot/efi"
  umount /boot/efi 2>/dev/null || umount -l /boot/efi 2>/dev/null || true

  log "Downloading nixos-infect"
  curl -fsSL https://raw.githubusercontent.com/elitak/nixos-infect/master/nixos-infect -o /root/nixos-infect
  chmod +x /root/nixos-infect
  sed -i '/rm -rf \$bootFs\.bak/i : "${bootFs:=/boot}"' /root/nixos-infect

  warn "Destructive step: Ubuntu will be replaced with NixOS."
  read -rp "Type YES to continue: " CONFIRM
  [[ "$CONFIRM" == "YES" ]] || { err "Aborted."; exit 1; }

  log "Starting nixos-infect (host will reboot)"
  doNetConf=y NIX_CHANNEL=nixos-25.11 bash -x /root/nixos-infect
}

phase_nixos() {
  require_root
  write_post_script
  bash "$POST_SCRIPT"
}

if [[ -f /etc/os-release ]]; then
  # shellcheck source=/dev/null
  source /etc/os-release
  case "${ID:-}" in
    ubuntu|debian) phase_ubuntu ;;
    nixos) phase_nixos ;;
    *) err "Unsupported OS: ${ID:-unknown}"; exit 1 ;;
  esac
else
  err "/etc/os-release missing"
  exit 1
fi
