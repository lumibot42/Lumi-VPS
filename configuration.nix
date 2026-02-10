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
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINkm1ttBzZryoAqdfV41IQuB1z/jWs1STdopUrovOjFU vps-access"
  ];

  users.users.lumi = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINkm1ttBzZryoAqdfV41IQuB1z/jWs1STdopUrovOjFU vps-access"
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
