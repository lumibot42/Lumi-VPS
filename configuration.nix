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

  # --- SSH (hardened, key-only, non-root) ---
  services.openssh.enable = true;
  services.openssh.settings = {
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
    PermitRootLogin = "no";
    AllowUsers = [ "lumi" ];
    MaxAuthTries = 3;
    LoginGraceTime = "20s";
    MaxSessions = 2;
    MaxStartups = "10:30:60";
    X11Forwarding = false;
    AllowAgentForwarding = false;
    AllowTcpForwarding = false;
    PermitTunnel = false;
  };

  # --- Users (mutable; SSH keys are provisioned at restore/runtime) ---
  users.users.lumi = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };

  security.sudo.wheelNeedsPassword = false;

  # --- Firewall (deny all, allow SSH only) ---
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];
  networking.firewall.allowPing = false;

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
    curl git nano htop btop tmux tree fastfetch
    # OpenClaw runtime + native build deps
    nodejs_22 gnumake gcc pkg-config cmake ninja python3 steam-run
  ];


  # --- User PATH reliability (survives reboot/login shell differences) ---
  environment.sessionVariables = {
    NPM_CONFIG_PREFIX = "$HOME/.npm-global";
    PATH = [ "$HOME/.npm-global/bin" ];
  };

  # Do NOT change after install
  system.stateVersion = "25.11";
}
