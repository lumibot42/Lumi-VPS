# 🚨 Lumi VPS Disaster Card (Quick Recovery)

Use this if the recovery script fails or you need a fast manual path.

**Goal:** fresh Ubuntu VPS → fresh NixOS → restore `/etc/nixos` → install OpenClaw.

Canonical repo: `git@github.com:lumibot42/Lumi-VPS.git`

---

## 0) Non-negotiable rules

- This host is **NixOS-first**. Persistent system changes must be done via NixOS config.
- Before system changes, check latest official docs:
  - https://nixos.org/manual/nixos/stable/
  - https://wiki.nixos.org/
- No hardcoded SSH authorized keys in `configuration.nix`.
- SSH keys are runtime-provisioned during restore.

---

## 1) Generate SSH key (if you don’t have one)

### Windows PowerShell
```powershell
ssh -V
ssh-keygen -t ed25519 -C "lumi-vps"
Get-Content $env:USERPROFILE\.ssh\id_ed25519.pub
```

### macOS/Linux
```bash
ssh-keygen -t ed25519 -C "lumi-vps"
cat ~/.ssh/id_ed25519.pub
```

Copy the full public key line.

---

## 2) Add key to GitHub

GitHub → Settings → SSH and GPG keys → New SSH key → paste public key.

Optional local test:
```bash
ssh -T git@github.com
```

---

## 3) Fresh Ubuntu prep (root)

```bash
ssh root@YOUR_SERVER_IP
apt update && apt install -y curl git
mkdir -p /root/.ssh && chmod 700 /root/.ssh
cat > /root/.ssh/authorized_keys
# paste your public key
# Ctrl+D
chmod 600 /root/.ssh/authorized_keys
```

---

## 4) Script path (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/lumibot42/Lumi-VPS/main/docs/recovery-migrate.sh -o /root/recovery-migrate.sh
chmod +x /root/recovery-migrate.sh
/root/recovery-migrate.sh --help
/root/recovery-migrate.sh --smoke-test
```

If smoke test passes:
```bash
/root/recovery-migrate.sh
```

> System reboots after Ubuntu → NixOS migration.

Reconnect:
```bash
ssh root@YOUR_SERVER_IP
```

Optional post-reboot smoke test:
```bash
/root/recovery-migrate.sh --smoke-test
```

Run restore phase:
```bash
/root/recovery-migrate.sh
```

---

## 5) Full manual fallback (if script fails)

### 5.1 Ubuntu → NixOS
```bash
umount /boot/efi 2>/dev/null || umount -l /boot/efi 2>/dev/null || true
curl -fsSL https://raw.githubusercontent.com/elitak/nixos-infect/master/nixos-infect -o /root/nixos-infect
chmod +x /root/nixos-infect
sed -i '/rm -rf \$bootFs\.bak/i : "${bootFs:=/boot}"' /root/nixos-infect
doNetConf=y NIX_CHANNEL=nixos-25.11 bash -x /root/nixos-infect
```

Reconnect after reboot:
```bash
ssh root@YOUR_SERVER_IP
```

### 5.2 Restore `/etc/nixos`
```bash
nix --extra-experimental-features 'nix-command flakes' profile add nixpkgs#git
hash -r
mkdir -p /root/.ssh && chmod 700 /root/.ssh
ssh-keyscan -H github.com >> /root/.ssh/known_hosts
chmod 600 /root/.ssh/known_hosts
```

If needed, generate server key and add to GitHub:
```bash
ssh-keygen -t ed25519 -N '' -f /root/.ssh/id_ed25519 -C "recovery@$(hostname)"
cat /root/.ssh/id_ed25519.pub
```

Test repo access:
```bash
git ls-remote git@github.com:lumibot42/Lumi-VPS.git
```

Clone + apply:
```bash
mkdir -p /etc/nixos
find /etc/nixos -mindepth 1 -maxdepth 1 -exec rm -rf {} +
git clone git@github.com:lumibot42/Lumi-VPS.git /etc/nixos
nixos-rebuild test --flake /etc/nixos#nixos
nixos-rebuild switch --flake /etc/nixos#nixos
```

### 5.3 Ensure admin SSH access (`lumi`)
```bash
id lumi >/dev/null 2>&1 || useradd -m -G wheel lumi
mkdir -p /home/lumi/.ssh
echo "YOUR_PUBLIC_KEY_HERE" > /home/lumi/.ssh/authorized_keys
chmod 700 /home/lumi/.ssh
chmod 600 /home/lumi/.ssh/authorized_keys
chown -R lumi:users /home/lumi/.ssh
```

### 5.4 Install OpenClaw manually (as `lumi`)
```bash
su - lumi
nix --extra-experimental-features 'nix-command flakes' profile add nixpkgs#nodejs_22
mkdir -p ~/.npm-global
npm config set prefix ~/.npm-global
grep -qxF 'export PATH="$HOME/.npm-global/bin:$PATH"' ~/.profile || echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.profile
grep -qxF 'export PATH="$HOME/.npm-global/bin:$PATH"' ~/.bashrc || echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.bashrc
export PATH="$HOME/.npm-global/bin:$PATH"
npm install -g openclaw
openclaw --version
```

Optional root shim:
```bash
ln -sf /home/lumi/.npm-global/bin/openclaw /usr/local/bin/openclaw
chmod 755 /usr/local/bin/openclaw
```

---

## 6) Restore OpenClaw state (if backup exists)

As `lumi`, restore:
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

---

## 7) Final verification

```bash
nix --extra-experimental-features 'nix-command flakes' flake check /etc/nixos
nixos-rebuild test --flake /etc/nixos#nixos
openclaw gateway status
openclaw status --deep
openclaw update status
openclaw security audit --deep
```

Expected: flake check passes, gateway running, no critical security findings.

---

## 8) Fast error map

- `recovery-migrate.sh: No such file` → re-download from GitHub raw URL
- `nix-command is disabled` → use `--extra-experimental-features 'nix-command flakes'`
- `Permission denied (publickey)` → add server `.pub` key to GitHub
- `openclaw: command not found` → export PATH + verify `~/.npm-global/bin/openclaw` + optional `/usr/local/bin` shim

---

Keep this card aligned with `docs/vps-rebuild-guide.md` whenever recovery flow changes.