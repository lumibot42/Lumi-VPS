# Ubuntu 24.04 → NixOS + OpenClaw Rebuild Guide

**Last updated:** 2026-02-10
**Canonical repo:** `git@github.com:lumibot42/Lumi-VPS.git`

---

## Preferred path (recommended)

Use the maintained recovery script from this repo:

```bash
# On fresh Ubuntu VPS as root
apt update && apt install -y git curl

# Preferred: pull directly from the public repo
curl -fsSL https://raw.githubusercontent.com/lumibot42/Lumi-VPS/main/docs/recovery-migrate.sh -o /root/recovery-migrate.sh

# Optional fallback: copy from local machine
# scp ./recovery-migrate.sh root@YOUR_SERVER_IP:/root/recovery-migrate.sh

chmod +x /root/recovery-migrate.sh
/root/recovery-migrate.sh
```

After reboot to NixOS, run the same script again:

```bash
/root/recovery-migrate.sh
```

If migration state is missing, it re-prompts and continues.

---

## What the recovery script now handles

### Ubuntu phase
- Collects required recovery inputs and stores them in `/root/.lumi-recovery/state.env`
- Installs Ubuntu prerequisites (`curl`, `git`)
- Configures root SSH authorized key
- Runs `nixos-infect`

### NixOS phase
- Rehydrates state (or re-prompts if state file is missing)
- Restores `/etc/nixos` from repo and runs flake rebuild
- Ensures admin/root SSH access and optional password setup
- **Auto-installs `git` on NixOS if missing**
- **Optional OpenClaw install** for admin user
  - Installs Node.js (`nodejs_22`) if needed
  - Sets npm prefix to `~/.npm-global`
  - Resolves PATH in `.profile`, `.bashrc`, `.zshrc`
  - Adds `/etc/profile.d/openclaw-path.sh`
  - Creates global shim: `/usr/local/bin/openclaw`
- **Post-install checks** print PATH + `which openclaw` + `openclaw --version` for root and admin user

---

## Manual path (fallback)

### 1) Prepare Ubuntu

```bash
ssh root@YOUR_SERVER_IP
apt update && apt install -y curl git
mkdir -p /root/.ssh && chmod 700 /root/.ssh
echo "YOUR_PUBLIC_KEY_HERE" > /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
umount /boot/efi 2>/dev/null || umount -l /boot/efi 2>/dev/null || true
```

### 2) Run nixos-infect

```bash
curl -fsSL https://raw.githubusercontent.com/elitak/nixos-infect/master/nixos-infect -o /root/nixos-infect
chmod +x /root/nixos-infect
sed -i '/rm -rf \$bootFs\.bak/i : "${bootFs:=/boot}"' /root/nixos-infect
doNetConf=y NIX_CHANNEL=nixos-25.11 bash -x /root/nixos-infect
```

Reconnect after reboot.

### 3) Restore `/etc/nixos`

```bash
rm -rf /etc/nixos/*
git clone git@github.com:lumibot42/Lumi-VPS.git /etc/nixos
nixos-rebuild switch --flake /etc/nixos#nixos
```

### 4) Install OpenClaw manually (if not done via script)

```bash
# as admin user
mkdir -p ~/.npm-global
npm config set prefix ~/.npm-global
echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.profile
source ~/.profile
npm install -g openclaw
```

Optional global shim:

```bash
sudo ln -sf /home/<admin-user>/.npm-global/bin/openclaw /usr/local/bin/openclaw
```

---

## Post-restore checklist

### Restore OpenClaw state (as admin user, e.g. `lumi`)
Restore from backup:
- `~/.openclaw/openclaw.json`
- `~/.openclaw/.env`
- `~/.openclaw/credentials/`
- `~/.openclaw/workspace/`

Then:

```bash
chmod 700 ~/.openclaw/credentials
openclaw gateway start
openclaw status --deep
openclaw models status
```

### Pull local heartbeat model

```bash
ollama pull qwen2.5:7b
```

### Verify terminal baseline

```bash
fastfetch
```

---

## Repo visibility note

- This repo is intentionally maintained as **public**.
- Recovery commands and examples in this guide assume public GitHub access.
- If visibility ever changes to private, use SSH deploy keys or token-auth HTTPS for clone/fetch.

## Current security/model baseline

- Primary model: `anthropic/claude-opus-4-6`
- Fallback model: `openai-codex/gpt-5.3-codex`
- Heartbeat model: `ollama/qwen2.5:7b`
- Discord elevated access: **disabled** (`tools.elevated.allowFrom.discord=[]`)
- Discord access policy: allowlisted to owner user ID only

---

## Notes

- Flake workflow is the source of truth:
  - Test: `sudo nixos-rebuild test --flake /etc/nixos#nixos`
  - Apply: `sudo nixos-rebuild switch --flake /etc/nixos#nixos`
- Keep secrets out of workspace where possible.
- Update this guide and `docs/DISASTER-CARD.md` whenever recovery flow changes.
