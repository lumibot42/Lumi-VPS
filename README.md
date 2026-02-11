# NixOS VPS Rebuild Runbook

This repository is the **source of truth** for rebuilding the VPS to a clean **NixOS + OpenClaw** state.

## 🚀 Go-time checklist (front page quick start)

Use this when you want the fastest safe rebuild path.

1) Fresh Ubuntu VPS as root
```bash
ssh root@YOUR_SERVER_IP
```

2) Install prerequisites
```bash
apt update && apt install -y curl git
```

3) Prepare root SSH directory
```bash
mkdir -p /root/.ssh && chmod 700 /root/.ssh
```

4) Paste your public key
```bash
cat > /root/.ssh/authorized_keys
```
(then paste key, press `Ctrl+D`)

5) Lock key file permissions
```bash
chmod 600 /root/.ssh/authorized_keys
```

6) Download recovery script
```bash
curl -fsSL https://raw.githubusercontent.com/lumibot42/Lumi-VPS/main/docs/recovery-migrate.sh -o /root/recovery-migrate.sh
```

7) Make script executable
```bash
chmod +x /root/recovery-migrate.sh
```

8) Show help
```bash
/root/recovery-migrate.sh --help
```

9) Run non-destructive preflight
```bash
/root/recovery-migrate.sh --smoke-test
```

10) Start migration
```bash
/root/recovery-migrate.sh
```
(system reboots)

11) Reconnect after reboot
```bash
ssh root@YOUR_SERVER_IP
```

12) Run post-reboot preflight
```bash
/root/recovery-migrate.sh --smoke-test
```

13) Run restore phase
```bash
/root/recovery-migrate.sh
```

14) Verify NixOS flake health
```bash
nix --extra-experimental-features 'nix-command flakes' flake check /etc/nixos
```

15) Verify rebuild test
```bash
nixos-rebuild test --flake /etc/nixos#nixos
```

16) Verify OpenClaw gateway
```bash
openclaw gateway status
```

17) Verify OpenClaw status
```bash
openclaw status --deep
```

18) Verify OpenClaw security
```bash
openclaw security audit --deep
```

If any step fails, follow:
- `docs/vps-rebuild-guide.md` (full manual fallback)
- `docs/DISASTER-CARD.md` (quick emergency path)

## Core operating rules

1. Treat this host as **NixOS-first** (not Ubuntu-style imperative admin).
2. Before system changes, check latest official docs:
   - https://nixos.org/manual/nixos/stable/
   - https://wiki.nixos.org/
3. Make declarative changes in `/etc/nixos` (tracked by this repo).
4. Run `nixos-rebuild test --flake ...` before `switch`.
5. Keep recovery docs in sync after any workflow change.

## Key security/recovery decisions

- `/etc/nixos` is canonical config.
- Flakes are required (`flake.nix` + `flake.lock`).
- **No hardcoded SSH authorized keys** in `configuration.nix`.
- SSH keys are provisioned at restore/runtime to support per-rebuild key rotation.

## Recovery entry points

- Full first-time + manual fallback guide:
  - `docs/vps-rebuild-guide.md`
- Quick emergency checklist:
  - `docs/DISASTER-CARD.md`
- Automation script:
  - `docs/recovery-migrate.sh`

## Script usage

On target host as root:

```bash
curl -fsSL https://raw.githubusercontent.com/lumibot42/Lumi-VPS/main/docs/recovery-migrate.sh -o /root/recovery-migrate.sh
chmod +x /root/recovery-migrate.sh
```

Flags:

```bash
/root/recovery-migrate.sh --help
/root/recovery-migrate.sh --smoke-test
```

Recommended flow:
1. Run `--smoke-test`
2. If clean, run `/root/recovery-migrate.sh`
3. After reboot to NixOS, run script again for restore phase

## Rebuild workflow (after restore)

```bash
sudo nixos-rebuild test --flake /etc/nixos#nixos
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

Then commit changes:

```bash
sudo git -C /etc/nixos add -A
sudo git -C /etc/nixos commit -m "describe change"
```

## Upgrade workflow

```bash
cd /etc/nixos
sudo nix flake update
sudo nixos-rebuild test --flake /etc/nixos#nixos
sudo nixos-rebuild switch --flake /etc/nixos#nixos
sudo git add flake.lock
sudo git commit -m "chore: flake update"
```

## OpenClaw backup checklist

- `~/.openclaw/openclaw.json`
- `~/.openclaw/.env`
- `~/.openclaw/credentials/` (mode 700)
- `~/.openclaw/workspace/`

## Notes

- Repo is intentionally public.
- If repo visibility changes to private, use SSH deploy key or token-auth HTTPS.
