#!/usr/bin/env bash
set -euo pipefail

# Ubuntu -> NixOS migration + NixOS restore helper
# Run as root. Prompts for host-specific values.

STATE_DIR="/root/.lumi-recovery"
STATE_FILE="$STATE_DIR/state.env"
POST_SCRIPT="$STATE_DIR/post-nixos-restore.sh"

log() { printf "\n[+] %s\n" "$*"; }
warn() { printf "\n[!] %s\n" "$*"; }
err() { printf "\n[x] %s\n" "$*" >&2; }

require_root() {
  [[ "${EUID:-$(id -u)}" -eq 0 ]] || { err "Run as root."; exit 1; }
}

ensure_state_dir() {
  mkdir -p "$STATE_DIR"
  chmod 700 "$STATE_DIR"
}

print_help() {
  cat <<'EOF'
Usage:
  recovery-migrate.sh [--smoke-test] [--help]

Modes:
  --smoke-test   Non-destructive preflight (checks prerequisites + repo auth)
  --help         Show this help text and exit

Default behavior (no flag):
  - On Ubuntu/Debian: run migration phase (includes nixos-infect)
  - On NixOS: run restore phase
EOF
}

prompt_common() {
  ensure_state_dir
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
  ensure_state_dir
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
    if ! GIT_SSH_COMMAND='ssh -o StrictHostKeyChecking=accept-new' git ls-remote "$NIXOS_REPO" >/dev/null 2>&1; then
      err "SSH access to repo failed: $NIXOS_REPO"
      exit 1
    fi
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

# Nix 2.4+ often needs experimental flags in non-interactive recovery shells.
nixx() {
  nix --extra-experimental-features 'nix-command flakes' "$@"
}

if ! command -v git >/dev/null 2>&1; then
  log "git not found on NixOS; installing it now"
  nixx profile add nixpkgs#git
  hash -r
fi

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

if [[ -d /etc/nixos/.git ]]; then
  log "Updating existing /etc/nixos"
  git -C /etc/nixos fetch --all --prune
  git -C /etc/nixos reset --hard origin/main
else
  log "Cloning /etc/nixos from repo"
  mkdir -p /etc/nixos
  find /etc/nixos -mindepth 1 -maxdepth 1 -exec rm -rf {} +
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

read -rp "Install OpenClaw for $ADMIN_USER now? [Y/n]: " INSTALL_OPENCLAW
if [[ -z "${INSTALL_OPENCLAW:-}" || "${INSTALL_OPENCLAW,,}" == "y" || "${INSTALL_OPENCLAW,,}" == "yes" ]]; then
  log "Installing OpenClaw prerequisites"

  # Ensure Node/npm are available for the admin user context (not just root).
  if ! su - "$ADMIN_USER" -c 'command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1'; then
    su - "$ADMIN_USER" -c "nix --extra-experimental-features 'nix-command flakes' profile add nixpkgs#nodejs_22"
  fi

  log "Installing OpenClaw as $ADMIN_USER"
  ADMIN_HOME="$(getent passwd "$ADMIN_USER" | cut -d: -f6)"
  [[ -n "$ADMIN_HOME" ]] || { err "Could not determine home for $ADMIN_USER"; exit 1; }

  su - "$ADMIN_USER" -c 'mkdir -p "$HOME/.npm-global"'
  su - "$ADMIN_USER" -c 'npm config set prefix "$HOME/.npm-global"'

  for RC in ".profile" ".bashrc" ".zshrc"; do
    su - "$ADMIN_USER" -c "touch \"$ADMIN_HOME/$RC\""
    su - "$ADMIN_USER" -c "grep -qxF 'export PATH=\"\$HOME/.npm-global/bin:\$PATH\"' \"$ADMIN_HOME/$RC\" || echo 'export PATH=\"\$HOME/.npm-global/bin:\$PATH\"' >> \"$ADMIN_HOME/$RC\""
  done

  # NixOS may not provide /etc/profile.d in mutable form; rely on user shell rc files + shim.
  su - "$ADMIN_USER" -c 'export PATH="$HOME/.npm-global/bin:$PATH"; npm install -g openclaw'

  if [[ -x "$ADMIN_HOME/.npm-global/bin/openclaw" ]]; then
    ln -sf "$ADMIN_HOME/.npm-global/bin/openclaw" /usr/local/bin/openclaw
    chmod 755 /usr/local/bin/openclaw
    log "OpenClaw installed: $ADMIN_HOME/.npm-global/bin/openclaw"
    log "Global shim installed: /usr/local/bin/openclaw"
    su - "$ADMIN_USER" -c 'openclaw --version' >/dev/null 2>&1 || warn "openclaw installed, but command not available in current non-login shell yet."
  else
    warn "OpenClaw install finished but binary not found in expected path."
  fi
else
  warn "Skipped OpenClaw installation."
fi

log "Post-install checks"
printf "\n[root] PATH=%s\n" "$PATH"
if command -v openclaw >/dev/null 2>&1; then
  printf "[root] which openclaw: %s\n" "$(command -v openclaw)"
  openclaw --version || warn "[root] openclaw found but --version failed"
else
  warn "[root] openclaw not found in PATH"
fi

su - "$ADMIN_USER" -c 'printf "\n['"$ADMIN_USER"'] PATH=%s\n" "$PATH"; if command -v openclaw >/dev/null 2>&1; then printf "['"$ADMIN_USER"'] which openclaw: %s\n" "$(command -v openclaw)"; openclaw --version || true; else echo "['"$ADMIN_USER"'] openclaw not found in PATH"; fi'

log "Done. Reconnect as: ssh $ADMIN_USER@$SERVER_ENDPOINT"
EOS
  chmod 700 "$POST_SCRIPT"
}

phase_ubuntu() {
  require_root
  prompt_common

  log "Installing Ubuntu prerequisites"
  apt update
  apt install -y curl git

  ensure_repo_auth
  write_post_script

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

phase_smoke_test() {
  require_root
  local failures=0

  log "Smoke test mode: non-destructive validation only"
  load_or_prompt_state

  if ! command -v git >/dev/null 2>&1; then
    warn "git not found"
    failures=$((failures+1))
  fi

  if ! command -v curl >/dev/null 2>&1; then
    warn "curl not found"
    failures=$((failures+1))
  fi

  if [[ "${ID:-}" == "nixos" ]]; then
    if ! command -v nixos-rebuild >/dev/null 2>&1; then
      warn "nixos-rebuild not found"
      failures=$((failures+1))
    fi
    if [[ -d /etc/nixos && -f /etc/nixos/flake.nix ]]; then
      if ! nixos-rebuild dry-build --flake "/etc/nixos#${FLAKE_HOST:-nixos}" >/dev/null; then
        warn "nixos-rebuild dry-build failed"
        failures=$((failures+1))
      fi
    else
      warn "/etc/nixos flake not present yet (expected before restore)"
    fi
  fi

  if command -v git >/dev/null 2>&1; then
    if ensure_repo_auth; then
      log "Repo auth check passed"
    else
      warn "Repo auth check failed"
      failures=$((failures+1))
    fi
  else
    warn "Skipping repo auth check because git is missing"
  fi

  if [[ $failures -gt 0 ]]; then
    err "Smoke test failed with $failures issue(s)."
    exit 1
  fi

  log "Smoke test passed. Recovery prerequisites look good."
}

MODE="run"
case "${1:-}" in
  --smoke-test) MODE="smoke" ;;
  --help|-h) print_help; exit 0 ;;
  "") ;;
  *) err "Unknown argument: ${1:-}. Supported: --smoke-test, --help"; exit 1 ;;
esac

if [[ -f /etc/os-release ]]; then
  # shellcheck source=/dev/null
  source /etc/os-release
  case "${ID:-}" in
    ubuntu|debian)
      if [[ "$MODE" == "smoke" ]]; then
        phase_smoke_test
      else
        phase_ubuntu
      fi
      ;;
    nixos)
      if [[ "$MODE" == "smoke" ]]; then
        phase_smoke_test
      else
        phase_nixos
      fi
      ;;
    *) err "Unsupported OS: ${ID:-unknown}"; exit 1 ;;
  esac
else
  err "/etc/os-release missing"
  exit 1
fi
