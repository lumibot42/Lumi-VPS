# Ubuntu 24.04 → NixOS + OpenClaw Rebuild Guide

**Last updated:** 2026-02-10
**Canonical repo:** `git@github.com:lumibot42/Lumi-VPS.git`

---

## Preferred path (recommended)

Use the maintained recovery script from this repo:

```bash
# On fresh Ubuntu VPS as root
apt update && apt install -y git curl

# Copy script from your local machine (private-repo safe)
# scp ./recovery-migrate.sh root@YOUR_SERVER_IP:/root/recovery-migrate.sh

# or if accessible via raw URL:
# curl -fsSL https://raw.githubusercontent.com/lumibot42/Lumi-VPS/main/docs/recovery-migrate.sh -o /root/recovery-migrate.sh

chmod +x /root/recovery-migrate.sh
/root/recovery-migrate.sh
```

After reboot to NixOS, run the same script again:

```bash
/root/recovery-migrate.sh
```

It now handles missing migration state by re-prompting.

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

---

## Post-restore checklist

### Restore OpenClaw state (as `lumi`)
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
