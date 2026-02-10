# Ubuntu 24.04 → NixOS + OpenClaw Rebuild Guide

**Last updated:** 2026-02-09
**Host:** IONOS VPS, AMD EPYC-Milan, 8 cores, 16GB RAM, 464GB disk

---

## Overview

Fresh Ubuntu 24.04 VPS → NixOS 25.11 with:
- Hardened SSH (key-only, no passwords)
- OpenClaw (Lumi) with Discord, Ollama heartbeats, Codex fallback
- fail2ban, auto-upgrades, nix GC
- Firewall: SSH only (port 22)

---

## Phase 1: SSH Key (local machine)

Skip if you already have a key.

```bash
ssh-keygen -t ed25519 -a 100 -C "vps-access"
cat ~/.ssh/id_ed25519.pub
```

Copy the full `ssh-ed25519 AAAA...` line.

---

## Phase 2: Prep Ubuntu

SSH into the fresh VPS as root:

```bash
ssh root@YOUR_SERVER_IP
```

Add your SSH key:

```bash
mkdir -p /root/.ssh && chmod 700 /root/.ssh
echo "YOUR_PUBLIC_KEY_HERE" > /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
```

Verify from local machine:

```bash
ssh root@YOUR_SERVER_IP "echo OK"
```

Unmount /boot/efi if mounted (prevents infect failure):

```bash
umount /boot/efi 2>/dev/null || umount -l /boot/efi 2>/dev/null || true
```

---

## Phase 3: Install NixOS (nixos-infect)

**⚠️ This destroys Ubuntu. Ensure you have console access as a safety net.**

```bash
curl -fsSL https://raw.githubusercontent.com/elitak/nixos-infect/master/nixos-infect -o /root/nixos-infect
chmod +x /root/nixos-infect

# Patch for Legacy/BIOS boot (safe to run on UEFI too)
sed -i '/rm -rf \$bootFs\.bak/i : "${bootFs:=/boot}"' /root/nixos-infect

# Run it
doNetConf=y NIX_CHANNEL=nixos-25.11 bash -x /root/nixos-infect
```

System reboots automatically. Wait 2–5 minutes, then reconnect:

```bash
ssh root@YOUR_SERVER_IP
```

Verify:

```bash
cat /etc/os-release | grep NixOS
```

---

## Phase 4: NixOS Configuration

Replace `/etc/nixos/configuration.nix` with the following.
**Replace `YOUR_SSH_PUBLIC_KEY` with your actual key (appears twice).**

```nix
{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./networking.nix
  ];

  # --- System ---
  networking.hostName = "nixos";
  networking.domain = "";

  # --- Nix ---
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.auto-optimise-store = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # --- Boot & Swap ---
  boot.tmp.cleanOnBoot = true;
  zramSwap.enable = true;
  services.logrotate.checkConfig = false; # NixOS/nix#8502

  # --- SSH (key-only, no passwords) ---
  services.openssh.enable = true;
  services.openssh.settings = {
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
    PermitRootLogin = "prohibit-password";
  };

  # --- Users (mutable — passwords set via passwd) ---
  users.users.root.openssh.authorizedKeys.keys = [
    "YOUR_SSH_PUBLIC_KEY"
  ];

  users.users.lumi = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "YOUR_SSH_PUBLIC_KEY"
    ];
  };

  security.sudo.wheelNeedsPassword = false;

  # --- Firewall (deny all, allow SSH only) ---
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];

  # --- Security ---
  services.fail2ban.enable = true;

  # --- Services ---
  services.ollama = {
    enable = true;
    acceleration = false; # CPU-only
  };

  system.autoUpgrade = {
    enable = true;
    allowReboot = false;
  };

  # --- Packages ---
  nixpkgs.config.allowUnfree = true;
  environment.systemPackages = with pkgs; [
    # Utilities
    curl git nano htop tmux tree
    # OpenClaw runtime + native build deps
    nodejs_22 gnumake gcc pkg-config cmake ninja python3 steam-run
  ];

  # Do NOT change after install
  system.stateVersion = "25.11";
}
```

Fix `networking.nix` — remove any empty IPv6 routes left by nixos-infect:

```bash
nano /etc/nixos/networking.nix
```

Look for empty strings in `defaultGateway6` or `ipv6.routes` and remove them. Add a backup DNS:

```nix
nameservers = [ "8.8.8.8" "1.1.1.1" ];
```

Apply:

```bash
nixos-rebuild switch
```

---

## Phase 5: Set Passwords

```bash
passwd root
passwd lumi
```

These are for console/sudo only — SSH uses keys.

---

## Phase 6: Install OpenClaw

Switch to lumi:

```bash
su - lumi
```

Set up npm global directory:

```bash
mkdir -p "$HOME/.npm-global"
npm config set prefix "$HOME/.npm-global"
echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

Install OpenClaw:

```bash
steam-run bash -lc 'export PATH="$HOME/.npm-global/bin:$PATH"; npm install -g openclaw@latest'
source ~/.bashrc
```

Onboard:

```bash
openclaw onboard
```

Follow the prompts:
- Choose your AI provider (Anthropic recommended as primary)
- Set up Discord bot if desired
- Run `openclaw doctor --repair` if any issues

Start the gateway:

```bash
openclaw gateway start
```

---

## Phase 7: Configure OpenClaw

### API Keys

Create `~/.openclaw/.env`:

```bash
OLLAMA_API_KEY=ollama-local
```

### Codex Fallback (optional, free with ChatGPT subscription)

```bash
openclaw onboard --auth-choice openai-codex
```

Follow the OAuth flow — open the URL in your browser, paste the redirect URL back.

### Key Config Settings

These can be set via `openclaw configure` or by editing `~/.openclaw/openclaw.json`:

```jsonc
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "anthropic/claude-opus-4-6",
        "fallbacks": ["openai-codex/gpt-5.3-codex"]
      },
      "elevatedDefault": "full",
      "heartbeat": {
        "model": "ollama/qwen2.5:7b"
      }
    }
  },
  "tools": {
    "elevated": {
      "enabled": true,
      "allowFrom": {
        "webchat": ["*"],
        "discord": ["*"]
      }
    }
  }
}
```

### Pull Ollama Model

```bash
ollama pull qwen2.5:7b
```

### Discord Bot

1. Create app at https://discord.com/developers/applications
2. Bot section → Reset Token → copy it
3. Enable: Message Content Intent, Server Members Intent
4. OAuth2 → URL Generator → scopes: `bot` → permissions: Send Messages, Read History, Add Reactions
5. Invite to your server with the generated URL
6. Set token in OpenClaw config: `channels.discord.token`

---

## Phase 8: Access Dashboard

The dashboard binds to localhost only. Access via SSH tunnel:

```bash
# From your local machine
ssh -L 18789:127.0.0.1:18789 lumi@YOUR_SERVER_IP
```

Then open: http://127.0.0.1:18789/

---

## Phase 9: Git-Track NixOS Config

```bash
sudo git -C /etc/nixos init
sudo git -C /etc/nixos config user.name "Lumi"
sudo git -C /etc/nixos config user.email "lumi@nixos"
sudo git -C /etc/nixos branch -m main
sudo git -C /etc/nixos add -A
sudo git -C /etc/nixos commit -m "Initial config"
```

Push to a **private** remote for disaster recovery:

```bash
sudo git -C /etc/nixos remote add origin git@github.com:YOU/nixos-config.git
sudo git -C /etc/nixos push -u origin main
```

---

## Backup Checklist

Everything needed to rebuild from scratch:

| What | Where | Contains |
|---|---|---|
| NixOS config | `/etc/nixos/` | System definition (git tracked) |
| OpenClaw config | `~/.openclaw/openclaw.json` | Gateway settings, channel config |
| API keys | `~/.openclaw/.env` | OLLAMA_API_KEY, etc. |
| OAuth tokens | `~/.openclaw/credentials/` | Codex, Discord tokens |
| Workspace | `~/.openclaw/workspace/` | Memory, identity, soul |

---

## Troubleshooting

| Problem | Solution |
|---|---|
| nixos-infect fails with `/boot/efi busy` | `umount -l /boot/efi` then retry |
| nixos-infect fails with `.bak missing destination` | Apply the bootFs patch (Phase 3) |
| `nixos-rebuild` fails with unfree package | Ensure `nixpkgs.config.allowUnfree = true;` |
| `openclaw: command not found` | `source ~/.bashrc` or check npm prefix |
| Network fails after rebuild | Check `networking.nix` for empty IPv6 routes |
| SSH locked out | Use provider console/VNC to fix `/etc/nixos` |
| Gateway won't start | `openclaw doctor --repair` then `openclaw gateway start` |
