# NixOS VPS Rebuild Runbook

## Source of truth
- `/etc/nixos` is the canonical system config.
- Flakes are the primary workflow (`flake.nix` + `flake.lock`) for reproducible rebuilds.

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

## Notes
- Keep changes declarative (no imperative drift).
- Keep comments concise and operational.
- Prefer `nixos-rebuild ... --flake` for reproducibility.
