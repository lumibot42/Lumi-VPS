# NixOS VPS Rebuild Runbook

## What this is
NixOS configuration for Erik's VPS running OpenClaw (Lumi).
- **Host:** IONOS VPS, IP 74.208.111.130
- **OS:** NixOS 25.11
- **Hardware:** AMD EPYC-Milan, 8 cores, 16GB RAM, 464GB disk

## Rebuild from scratch

### 1. Provision a fresh VPS
Any VPS with NixOS support, or use nixos-infect on a Debian/Ubuntu base:
```bash
curl https://raw.githubusercontent.com/elitak/nixos-infect/master/nixos-infect | NIX_CHANNEL=nixos-25.11 bash -x
```

### 2. Clone this config
```bash
cd /etc/nixos
git clone <REMOTE_URL> .
```

### 3. Update hardware-configuration.nix
If the hardware changed, regenerate:
```bash
nixos-generate-config --show-hardware-config > hardware-configuration.nix
```

### 4. Update networking.nix
Update IP, gateway, and interface name to match the new VPS.

### 5. Rebuild
```bash
nixos-rebuild switch
```

### 6. Set passwords
```bash
passwd root
passwd lumi
```

### 7. Install OpenClaw
```bash
su - lumi
npm install -g openclaw
openclaw onboard
```

### 8. Restore OpenClaw state
Copy from backup:
- `~/.openclaw/openclaw.json` — config
- `~/.openclaw/.env` — API keys
- `~/.openclaw/credentials/` — OAuth tokens
- `~/.openclaw/workspace/` — memory, identity, etc.

### 9. Pull Ollama model
```bash
ollama pull qwen2.5:7b
```

### 10. Start OpenClaw
```bash
openclaw gateway start
```

## Files
- `configuration.nix` — main system config (source of truth)
- `hardware-configuration.nix` — auto-detected hardware (regenerate per-host)
- `networking.nix` — static IP and routes (update per-host)

## Backup checklist
- [ ] `/etc/nixos/` — this repo
- [ ] `~/.openclaw/openclaw.json` — OpenClaw config
- [ ] `~/.openclaw/.env` — environment secrets
- [ ] `~/.openclaw/credentials/` — OAuth tokens
- [ ] `~/.openclaw/workspace/` — Lumi's memory and identity
