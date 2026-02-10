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

## 3) Download recovery script
```bash
curl -fsSL https://raw.githubusercontent.com/lumibot42/Lumi-VPS/main/docs/recovery-migrate.sh -o /root/recovery-migrate.sh
chmod +x /root/recovery-migrate.sh
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
This restores `/etc/nixos` and applies flake config.

## 7) Restore OpenClaw state backups
As `lumi`, restore:
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
