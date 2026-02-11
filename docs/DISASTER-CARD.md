# 🚨 Lumi VPS Disaster Recovery Card

Use this when rebuilding from **fresh Ubuntu**.

## 1) Connect to VPS
```bash
ssh root@YOUR_SERVER_IP
```

## 2) Install prerequisites
```bash
apt update && apt install -y git curl
```

## 3) Get recovery script (public repo)

### Option A (recommended): pull from GitHub raw URL
```bash
curl -fsSL https://raw.githubusercontent.com/lumibot42/Lumi-VPS/main/docs/recovery-migrate.sh -o /root/recovery-migrate.sh
chmod +x /root/recovery-migrate.sh
```

### Option B (fallback): copy from your local machine
```bash
scp ./recovery-migrate.sh root@YOUR_SERVER_IP:/root/recovery-migrate.sh
ssh root@YOUR_SERVER_IP 'chmod +x /root/recovery-migrate.sh'
```

## 4) Optional preflight (safe dry check)
```bash
/root/recovery-migrate.sh --smoke-test
```
This validates prerequisites and repo auth only (no destructive changes).

**Strongly recommended:** run this right before migration on any fresh rebuild.

Need flags quick reference:
```bash
/root/recovery-migrate.sh --help
```

## 5) Run migration (Ubuntu -> NixOS)
```bash
/root/recovery-migrate.sh
```
Prompts for:
- admin username
- server endpoint
- SSH public key
- NixOS repo URL (`git@github.com:lumibot42/Lumi-VPS.git`)
- flake host (`nixos` default)

No SSH keys are hardcoded in the script; it prompts when needed.

Critical: paste the correct SSH public key when prompted, or you can lock yourself out.

If you need to generate a key from Windows, see **"Windows: SSH key setup (beginner-friendly)"** in `docs/vps-rebuild-guide.md`.

> System will reboot automatically.

## 6) Reconnect after reboot (now NixOS)
```bash
ssh root@YOUR_SERVER_IP
```

## 7) Optional post-reboot smoke test
```bash
/root/recovery-migrate.sh --smoke-test
```

## 8) Run restore phase
```bash
/root/recovery-migrate.sh
```
If prior state is missing, script re-prompts and continues.

### Restore phase now also handles:
- `git` install on NixOS (if missing)
- optional OpenClaw install for admin user
- User shell PATH entries (`.profile`, `.bashrc`, `.zshrc`) and `/usr/local/bin/openclaw` shim
- post-install verification output (`PATH`, `which openclaw`, `openclaw --version` for root + admin)

## 9) Restore OpenClaw state backups
As admin user (e.g., `lumi`), restore:
- `~/.openclaw/openclaw.json`
- `~/.openclaw/.env`
- `~/.openclaw/credentials/`
- `~/.openclaw/workspace/`

Then fix perms:
```bash
chmod 700 ~/.openclaw/credentials
```

## 10) Failsafe if git install fails on NixOS
Run as root:
```bash
nix --extra-experimental-features 'nix-command flakes' profile add nixpkgs#git
hash -r
git --version
```

If needed, use one-shot git without permanent install:
```bash
nix --extra-experimental-features 'nix-command flakes' shell nixpkgs#git -c git --version
```

## 11) Failsafe if OpenClaw install fails
Run as admin user (example `lumi`):
```bash
command -v node || nix --extra-experimental-features 'nix-command flakes' profile add nixpkgs#nodejs_22
mkdir -p ~/.npm-global
npm config set prefix ~/.npm-global
grep -qxF 'export PATH="$HOME/.npm-global/bin:$PATH"' ~/.profile || echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.profile
export PATH="$HOME/.npm-global/bin:$PATH"
npm install -g openclaw
openclaw --version
```

Optional root shim:
```bash
ln -sf /home/<admin-user>/.npm-global/bin/openclaw /usr/local/bin/openclaw
chmod 755 /usr/local/bin/openclaw
```

## 12) Verify services
```bash
openclaw gateway status
openclaw status --deep
openclaw models status
fastfetch
```

---

## Ongoing Rule
Keep this card current whenever recovery steps change.
- Update this file in repo: `docs/DISASTER-CARD.md`
- Commit with: `docs: update disaster recovery card`
