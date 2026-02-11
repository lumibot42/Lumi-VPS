# NixOS VPS Rebuild Runbook

This repository is the **source of truth** for rebuilding the VPS to a clean **NixOS + OpenClaw** state.

## 🚀 Go-time checklist (front page quick start)

Use this when you want the fastest safe rebuild path.

```bash
# 1) Fresh Ubuntu VPS as root
ssh root@YOUR_SERVER_IP
apt update && apt install -y curl git
mkdir -p /root/.ssh && chmod 700 /root/.ssh
cat > /root/.ssh/authorized_keys
# paste your public key, then Ctrl+D
chmod 600 /root/.ssh/authorized_keys

# 2) Pull recovery script
curl -fsSL https://raw.githubusercontent.com/lumibot42/Lumi-VPS/main/docs/recovery-migrate.sh -o /root/recovery-migrate.sh
chmod +x /root/recovery-migrate.sh

# 3) Preflight + run
/root/recovery-migrate.sh --help
/root/recovery-migrate.sh --smoke-test
/root/recovery-migrate.sh
# system reboots

# 4) Reconnect and complete restore
ssh root@YOUR_SERVER_IP
/root/recovery-migrate.sh --smoke-test
/root/recovery-migrate.sh

# 5) Final verification
nix --extra-experimental-features 'nix-command flakes' flake check /etc/nixos
nixos-rebuild test --flake /etc/nixos#nixos
openclaw gateway status
openclaw status --deep
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
