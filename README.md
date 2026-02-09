# NixOS VPS Rebuild Runbook

## Source of truth
- `/etc/nixos` is the canonical system config.
- Uses both classic `configuration.nix` and flake entrypoint (`flake.nix`) for reproducible rebuilds.

## Rebuild commands

### Standard (current host)
```bash
sudo nixos-rebuild switch
```

### Reproducible (pinned via flake.lock)
```bash
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

## Update workflow (best practice)

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
