{ lib, ... }: {
  # This file was populated at runtime with the networking
  # details gathered from the active system.
  networking = {
    nameservers = [ "8.8.8.8" "1.1.1.1" ];
    defaultGateway = "74.208.111.1";
    dhcpcd.enable = false;
    usePredictableInterfaceNames = lib.mkForce true;
    interfaces = {
      ens6 = {
        ipv4.addresses = [
          { address = "74.208.111.130"; prefixLength = 32; }
        ];
        ipv6.addresses = [
          { address = "fe80::1:9aff:fef8:e684"; prefixLength = 64; }
        ];
        ipv4.routes = [ { address = "74.208.111.1"; prefixLength = 32; } ];
      };
    };
  };
  services.udev.extraRules = ''
    ATTR{address}=="02:01:9a:f8:e6:84", NAME="ens6"
  '';
}
