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

## 4) Run migration (Ubuntu -> NixOS)
```bash
/root/recovery-migrate.sh
```
Prompts for:
- admin username
- server endpoint
- SSH public key
- NixOS repo URL (`git@github.com:lumibot42/Lumi-VPS.git`)
- flake host (`nixos` default)

> System will reboot automatically.

## 5) Reconnect after reboot (now NixOS)
```bash
ssh root@YOUR_SERVER_IP
```

## 6) Run restore phase
```bash
/root/recovery-migrate.sh
```
If prior state is missing, script re-prompts and continues.

### Restore phase now also handles:
- `git` install on NixOS (if missing)
- optional OpenClaw install for admin user
- PATH setup across `.profile`, `.bashrc`, `.zshrc`
- `/etc/profile.d/openclaw-path.sh`
- `/usr/local/bin/openclaw` shim
- post-install verification output (`PATH`, `which openclaw`, `openclaw --version` for root + admin)

## 7) Restore OpenClaw state backups
As admin user (e.g., `lumi`), restore:
- `~/.openclaw/openclaw.json`
- `~/.openclaw/.env`
- `~/.openclaw/credentials/`
- `~/.openclaw/workspace/`

Then fix perms:
```bash
chmod 700 ~/.openclaw/credentials
```

## 8) Verify services
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
