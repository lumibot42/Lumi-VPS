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

If `/root/recovery-migrate.sh` is missing (common after reimage), re-download it:

```bash
curl -fsSL https://raw.githubusercontent.com/lumibot42/Lumi-VPS/main/docs/recovery-migrate.sh -o /root/recovery-migrate.sh
chmod +x /root/recovery-migrate.sh
/root/recovery-migrate.sh
```

If migration state is missing, it re-prompts and continues.

No SSH keys are hardcoded in the recovery script. It prompts for key details (or asks to generate a key) at runtime.

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
  - Uses user shell rc PATH updates (`.profile`, `.bashrc`, `.zshrc`) + runtime PATH export
  - Creates global shim: `/usr/local/bin/openclaw`
- **Post-install checks** print PATH + `which openclaw` + `openclaw --version` for root and admin user

---

## Windows: SSH key setup (beginner-friendly)

If you're on Windows and have never used SSH keys, do this first. You only need to do it once per computer.

### A) Open PowerShell

1. Press **Start**
2. Type **PowerShell**
3. Open **Windows PowerShell** (or **Terminal** with a PowerShell tab)

### B) Check that OpenSSH is available

Run:

```powershell
ssh -V
```

- If it prints a version (for example `OpenSSH_for_Windows_9.x`), continue.
- If it says command not found, install OpenSSH Client:
  - **Settings → Apps → Optional Features → Add a feature → OpenSSH Client → Install**
  - Re-open PowerShell and run `ssh -V` again.

### C) Generate a new SSH key pair

Run:

```powershell
ssh-keygen -t ed25519 -C "lumi-vps"
```

When prompted:

- **Enter file in which to save the key** → press **Enter** (accept default)
- **Enter passphrase** → optional (recommended, but can be empty)
- **Enter same passphrase again**

This creates:
- Private key: `C:\Users\<you>\.ssh\id_ed25519` (keep secret)
- Public key: `C:\Users\<you>\.ssh\id_ed25519.pub` (safe to share)

### D) Copy your public key

Run:

```powershell
Get-Content $env:USERPROFILE\.ssh\id_ed25519.pub
```

Copy the full line starting with `ssh-ed25519`.

### E) Add key to GitHub

1. Go to **GitHub → Settings → SSH and GPG keys**
2. Click **New SSH key**
3. Title: `Lumi VPS` (or similar)
4. Key type: **Authentication Key**
5. Paste the full key line
6. Click **Add SSH key**

### F) Trust GitHub host key (first-use prompt)

Run:

```powershell
ssh -T git@github.com
```

- If asked to continue connecting, type `yes`
- Successful auth usually ends with:
  - `Hi <username>! You've successfully authenticated...`

### G) Test repo access

Run:

```powershell
git ls-remote git@github.com:lumibot42/Lumi-VPS.git
```

If you see commit hashes/refs, SSH auth is working.

### Common mistakes

- Sharing `id_ed25519` instead of `id_ed25519.pub` (never share private key)
- Copying only part of the public key line
- Adding key to wrong GitHub account
- Running in old shell session after installing OpenSSH (open a new PowerShell)

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

## Failsafe manual recovery (if script automation fails)

Use this section if either `git` install or `openclaw` install fails during restore.

### A) Failsafe: install git on NixOS manually

Run as `root`:

```bash
# ensure nix-command + flakes are available in this shell invocation
nix --extra-experimental-features 'nix-command flakes' profile add nixpkgs#git
hash -r
git --version
```

If that still fails, use ephemeral shell just to run git commands:

```bash
nix --extra-experimental-features 'nix-command flakes' shell nixpkgs#git -c git --version
```

Then clone/restore config:

```bash
rm -rf /etc/nixos/*
git clone git@github.com:lumibot42/Lumi-VPS.git /etc/nixos
nixos-rebuild switch --flake /etc/nixos#nixos
```

### B) Failsafe: install OpenClaw manually on NixOS

Run as admin user (example: `lumi`):

```bash
# 1) ensure Node.js and npm exist
command -v node || nix --extra-experimental-features 'nix-command flakes' profile add nixpkgs#nodejs_22
command -v npm || nix --extra-experimental-features 'nix-command flakes' profile add nixpkgs#nodejs_22

# 2) configure user npm global prefix
mkdir -p ~/.npm-global
npm config set prefix ~/.npm-global

# 3) ensure PATH for future logins
grep -qxF 'export PATH="$HOME/.npm-global/bin:$PATH"' ~/.profile || echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.profile
grep -qxF 'export PATH="$HOME/.npm-global/bin:$PATH"' ~/.bashrc || echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.bashrc

# 4) load PATH in current shell and install
export PATH="$HOME/.npm-global/bin:$PATH"
npm install -g openclaw
openclaw --version
```

Optional global shim (run as root):

```bash
ln -sf /home/<admin-user>/.npm-global/bin/openclaw /usr/local/bin/openclaw
chmod 755 /usr/local/bin/openclaw
```

### C) If `openclaw` command still not found

```bash
# check expected binary
ls -l /home/<admin-user>/.npm-global/bin/openclaw

# temporary path in current shell
export PATH="/home/<admin-user>/.npm-global/bin:$PATH"
openclaw --version

# verify from a clean login shell
su - <admin-user> -c 'command -v openclaw && openclaw --version'
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
