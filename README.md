# NixOS VPS Rebuild Runbook

## Source of truth
- `/etc/nixos` is the canonical system config.
- Flakes are the primary workflow (`flake.nix` + `flake.lock`) for reproducible rebuilds.
- Recovery automation lives in `docs/recovery-migrate.sh`.

## Recovery workflow (Ubuntu -> NixOS)

On Ubuntu (root):
```bash
apt update && apt install -y git curl
curl -fsSL https://raw.githubusercontent.com/lumibot42/Lumi-VPS/main/docs/recovery-migrate.sh -o /root/recovery-migrate.sh
chmod +x /root/recovery-migrate.sh
/root/recovery-migrate.sh
```

After reboot to NixOS (root):
```bash
/root/recovery-migrate.sh
```

The script now supports:
- Missing state re-prompt
- Auto-install of `git` on NixOS (if missing)
- Optional OpenClaw install for admin user
- PATH resolution during OpenClaw install (`.profile`, `.bashrc`, `.zshrc`) and global shim `/usr/local/bin/openclaw`
- Global shim at `/usr/local/bin/openclaw`
- Post-install verification (`PATH`, `which openclaw`, `openclaw --version`)

## Rebuild workflow (flake-first)

1. Edit config in `/etc/nixos`
2. Test build:
```bash
sudo nixos-rebuild test --flake /etc/nixos#nixos
```
3. Apply:
```bash
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```
4. Commit:
```bash
sudo git -C /etc/nixos add -A
sudo git -C /etc/nixos commit -m "describe change"
```

## Upgrade workflow

```bash
cd /etc/nixos
sudo nix flake update
sudo nixos-rebuild switch --flake /etc/nixos#nixos
sudo git add flake.lock
sudo git commit -m "chore: flake update"
```

## Legacy fallback (emergency only)
Use only if flake entrypoint is unavailable:
```bash
sudo nixos-rebuild switch
```

## Disaster recovery checklist
- [ ] Push `/etc/nixos` repo to private remote
- [ ] Backup `~/.openclaw/openclaw.json`
- [ ] Backup `~/.openclaw/.env`
- [ ] Backup `~/.openclaw/credentials/` (mode 700)
- [ ] Backup `~/.openclaw/workspace/`

## Repo visibility note
- This repository is intentionally **public**.
- Commands in this runbook assume direct public GitHub access.

## Notes
- Keep changes declarative (no imperative drift).
- Keep comments concise and operational.
- Prefer `nixos-rebuild ... --flake` for reproducibility.
- Keep `README.md`, `docs/vps-rebuild-guide.md`, and `docs/DISASTER-CARD.md` in sync after workflow changes.
