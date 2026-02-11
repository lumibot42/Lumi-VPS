# Ubuntu VPS → Fresh NixOS + OpenClaw (First-Time, Script-Failure-Proof Guide)

**Last updated:** 2026-02-11  
**Canonical repo:** `git@github.com:lumibot42/Lumi-VPS.git`

---

## Read this first (important)

This guide is written for a **total first-timer** and for a **worst-case scenario** where automation fails.

You can follow this with:
- no existing SSH keys
- no existing NixOS knowledge
- no working recovery script

### Core rule for future maintenance (for any agent/operator)

This host is a **NixOS system**. Any system changes must be done in NixOS context:

1. Prefer declarative changes in `/etc/nixos/*.nix`
2. Use `nixos-rebuild test --flake ...` before `switch`
3. Use official docs first before system changes:
   - https://nixos.org/manual/nixos/stable/
   - https://wiki.nixos.org/

Do **not** treat this like Ubuntu when changing persistent system config.

---

## Goal

End state should be:
1. VPS running fresh NixOS
2. `/etc/nixos` restored from `lumibot42/Lumi-VPS`
3. SSH hardened + reachable
4. OpenClaw installed and runnable
5. OpenClaw state restored (if backup exists)

---

## Go-time checklist (copy/paste quick flow)

Use this when you just need the shortest safe path.

### 1) Fresh Ubuntu prep (root)

```bash
ssh root@YOUR_SERVER_IP
apt update && apt install -y curl git
mkdir -p /root/.ssh && chmod 700 /root/.ssh
cat > /root/.ssh/authorized_keys
```

Paste your public key, then press `Ctrl+D`:

```bash
chmod 600 /root/.ssh/authorized_keys
```

### 2) Pull script

```bash
curl -fsSL https://raw.githubusercontent.com/lumibot42/Lumi-VPS/main/docs/recovery-migrate.sh -o /root/recovery-migrate.sh
chmod +x /root/recovery-migrate.sh
```

### 3) Non-destructive preflight

```bash
/root/recovery-migrate.sh --help
/root/recovery-migrate.sh --smoke-test
```

### 4) Run migration

```bash
/root/recovery-migrate.sh
```

_System reboots during Ubuntu → NixOS._

### 5) Reconnect + restore

```bash
ssh root@YOUR_SERVER_IP
/root/recovery-migrate.sh --smoke-test
/root/recovery-migrate.sh
```

### 6) Final verify

```bash
nix --extra-experimental-features 'nix-command flakes' flake check /etc/nixos
nixos-rebuild test --flake /etc/nixos#nixos
openclaw gateway status
openclaw status --deep
openclaw security audit --deep
```

If anything fails, continue with the manual fallback phases below.

---

## Phase 0 — What you need before starting

Have these ready:
- VPS provider console access (very important if SSH breaks)
- VPS public IPv4 (or DNS)
- Your local machine terminal (Windows/macOS/Linux)
- GitHub account access (to add SSH key)

---

## Phase 1 — Create SSH keys (if you don’t have any)

## Windows (PowerShell)

1. Open PowerShell
2. Check SSH client:

```powershell
ssh -V
```

If command missing: install **OpenSSH Client** in Windows Optional Features.

3. Create key:

```powershell
ssh-keygen -t ed25519 -C "lumi-vps"
```

Press Enter for default key location.

4. Print public key:

```powershell
Get-Content $env:USERPROFILE\.ssh\id_ed25519.pub
```

Copy the full line (`ssh-ed25519 ...`).

## macOS/Linux

```bash
ssh-keygen -t ed25519 -C "lumi-vps"
cat ~/.ssh/id_ed25519.pub
```

Copy full public key line.

---

## Phase 2 — Add your key to GitHub (for repo access)

1. GitHub → Settings → SSH and GPG keys
2. New SSH key
3. Title: `Lumi VPS` (or similar)
4. Paste your **public key**
5. Save

Test from your local machine:

```bash
ssh -T git@github.com
```

Expected: authentication success message.

---

## Phase 3 — Prepare fresh Ubuntu VPS (root)

SSH into fresh Ubuntu VPS as root:

```bash
ssh root@YOUR_SERVER_IP
```

Install minimum tools:

```bash
apt update && apt install -y curl git
```

Install your SSH public key for root access:

```bash
mkdir -p /root/.ssh && chmod 700 /root/.ssh
cat > /root/.ssh/authorized_keys
# paste your public key, then press Enter
# press Ctrl+D to save
chmod 600 /root/.ssh/authorized_keys
```

---

## Phase 4 — Try automation first (safe approach)

Get script:

```bash
curl -fsSL https://raw.githubusercontent.com/lumibot42/Lumi-VPS/main/docs/recovery-migrate.sh -o /root/recovery-migrate.sh
chmod +x /root/recovery-migrate.sh
```

Run smoke test first:

```bash
/root/recovery-migrate.sh --smoke-test
```

If smoke test passes, run migration:

```bash
/root/recovery-migrate.sh
```

If script fails at any point, continue with manual phases below.

---

## Phase 5 — Manual Ubuntu → NixOS migration (no script)

⚠️ This is destructive (Ubuntu replaced by NixOS).

```bash
umount /boot/efi 2>/dev/null || umount -l /boot/efi 2>/dev/null || true
curl -fsSL https://raw.githubusercontent.com/elitak/nixos-infect/master/nixos-infect -o /root/nixos-infect
chmod +x /root/nixos-infect
sed -i '/rm -rf \$bootFs\.bak/i : "${bootFs:=/boot}"' /root/nixos-infect
doNetConf=y NIX_CHANNEL=nixos-25.11 bash -x /root/nixos-infect
```

System will reboot.

Reconnect:

```bash
ssh root@YOUR_SERVER_IP
```

---

## Phase 6 — Manual NixOS recovery of `/etc/nixos`

### 6.1 Ensure git exists on NixOS

```bash
nix --extra-experimental-features 'nix-command flakes' profile add nixpkgs#git
hash -r
git --version
```

### 6.2 Ensure root SSH can reach GitHub

```bash
mkdir -p /root/.ssh && chmod 700 /root/.ssh
ssh-keyscan -H github.com >> /root/.ssh/known_hosts
chmod 600 /root/.ssh/known_hosts
```

If key missing on server, generate one and add to GitHub:

```bash
ssh-keygen -t ed25519 -N '' -f /root/.ssh/id_ed25519 -C "recovery@$(hostname)"
cat /root/.ssh/id_ed25519.pub
```

Paste that pubkey into GitHub SSH keys, then test:

```bash
git ls-remote git@github.com:lumibot42/Lumi-VPS.git
```

### 6.3 Restore `/etc/nixos` from repo

```bash
mkdir -p /etc/nixos
find /etc/nixos -mindepth 1 -maxdepth 1 -exec rm -rf {} +
git clone git@github.com:lumibot42/Lumi-VPS.git /etc/nixos
```

### 6.4 Apply config safely

```bash
nixos-rebuild test --flake /etc/nixos#nixos
nixos-rebuild switch --flake /etc/nixos#nixos
```

---

## Phase 7 — Create admin user + SSH access (if needed)

If `lumi` user is missing:

```bash
id lumi >/dev/null 2>&1 || useradd -m -G wheel lumi
```

Set SSH key for lumi:

```bash
mkdir -p /home/lumi/.ssh
echo "YOUR_PUBLIC_KEY_HERE" > /home/lumi/.ssh/authorized_keys
chmod 700 /home/lumi/.ssh
chmod 600 /home/lumi/.ssh/authorized_keys
chown -R lumi:users /home/lumi/.ssh
```

Optional: set password

```bash
passwd lumi
```

---

## Phase 8 — Install OpenClaw manually (if script fails)

Run as `lumi` user:

```bash
su - lumi
```

Install Node.js/npm in `lumi` context:

```bash
nix --extra-experimental-features 'nix-command flakes' profile add nixpkgs#nodejs_22
```

Set npm global directory and PATH:

```bash
mkdir -p ~/.npm-global
npm config set prefix ~/.npm-global
grep -qxF 'export PATH="$HOME/.npm-global/bin:$PATH"' ~/.profile || echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.profile
grep -qxF 'export PATH="$HOME/.npm-global/bin:$PATH"' ~/.bashrc || echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.bashrc
export PATH="$HOME/.npm-global/bin:$PATH"
```

Install OpenClaw:

```bash
npm install -g openclaw
openclaw --version
```

Optional system shim (run as root in separate shell):

```bash
ln -sf /home/lumi/.npm-global/bin/openclaw /usr/local/bin/openclaw
chmod 755 /usr/local/bin/openclaw
```

---

## Phase 9 — Restore OpenClaw state (if backup exists)

As `lumi`, restore:
- `~/.openclaw/openclaw.json`
- `~/.openclaw/.env`
- `~/.openclaw/credentials/`
- `~/.openclaw/workspace/`

Then fix permissions:

```bash
chmod 700 ~/.openclaw/credentials
```

Start + verify:

```bash
openclaw gateway start
openclaw status --deep
openclaw models status
```

---

## Phase 10 — Final verification checklist

Run and confirm success:

```bash
# ssh still works
ss -ltnp | grep ':22' || true

# config health
nix --extra-experimental-features 'nix-command flakes' flake check /etc/nixos
nixos-rebuild test --flake /etc/nixos#nixos

# OpenClaw
openclaw gateway status
openclaw status --deep
openclaw update status
openclaw security audit --deep
```

Expected:
- no critical OpenClaw security findings
- gateway running
- flake checks pass

---

## Common failure map (quick triage)

### `recovery-migrate.sh: No such file`
Re-download it:
```bash
curl -fsSL https://raw.githubusercontent.com/lumibot42/Lumi-VPS/main/docs/recovery-migrate.sh -o /root/recovery-migrate.sh
chmod +x /root/recovery-migrate.sh
```

### `nix-command is disabled`
Use explicit features:
```bash
nix --extra-experimental-features 'nix-command flakes' ...
```

### `Permission denied (publickey)` on clone
- Generate server key (`ssh-keygen ...`)
- Add `.pub` key to GitHub
- Retry `git ls-remote`

### `openclaw: command not found`
```bash
export PATH="$HOME/.npm-global/bin:$PATH"
command -v openclaw
openclaw --version
```
If needed, create `/usr/local/bin/openclaw` shim.

---

## Design decisions for this repo

- This repo is the canonical restore source for this VPS.
- Target outcome: clean NixOS + OpenClaw recovery.
- **No hardcoded SSH authorized keys** in `configuration.nix`.
- SSH keys are runtime-provisioned per rebuild for key rotation.

---

## Operator note for future agents

When changing system behavior for this host:
1. Read latest NixOS docs first.
2. Make declarative edits in `/etc/nixos` / repo files.
3. Run `nixos-rebuild test --flake ...` before `switch`.
4. Keep recovery docs updated whenever workflow changes.
