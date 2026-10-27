# hardware-configuration.nix
# Lenovo compacta de escritorio — Intel Core Ultra 9 (iGPU) + NVIDIA RTX discreta.
# OJO: esto está escrito a mano como plantilla. Lo correcto es generarlo en la máquina
# con `nixos-generate-config` para que los fileSystems salgan con sus UUID reales.

{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  ####################################################################
  # KERNEL / MÓDULOS (NVMe + USB, para que arranque desde el USB4)
  ####################################################################

  boot.initrd.availableKernelModules =
    [ "xhci_pci" "thunderbolt" "nvme" "usb_storage" "uas" "sd_mod" "ahci" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  # Core Ultra 9 = Intel, microcódigo al día
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  hardware.enableRedistributableFirmware = true;

  ####################################################################
  # SISTEMA DE ARCHIVOS (por etiqueta, para que el USB sea portátil)
  #   al formatear:  mkfs.ext4 -L NIXUSB /dev/sdX2   y   mkfs.fat -F32 -n BOOT /dev/sdX1
  ####################################################################

  fileSystems."/" =
    { device = "/dev/disk/by-label/NIXUSB";
      fsType = "ext4";
      options = [ "noatime" ];
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-label/BOOT";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };

  # sin swap en disco: ya hay zram en configuration.nix
  swapDevices = [ ];

  ####################################################################
  # GPU NVIDIA — aquí NO es para escritorio (seguimos en TTY),
  # es para que hashcat tire de la RTX por CUDA. Ahí está la gracia.
  ####################################################################

  # instala el driver aunque X nunca arranque (xserver.enable sigue en false)
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.graphics.enable = true;

  hardware.nvidia = {
    open = true;                 # RTX moderna (Turing+): módulos abiertos
    modesetting.enable = true;
    nvidiaSettings = false;      # no hay GUI que configurar
    powerManagement.enable = false;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # nota: si el driver no compila contra linuxPackages_latest (pasa a veces),
  # bajar a `pkgs.linuxPackages` en configuration.nix y listo
  nixpkgs.config.cudaSupport = lib.mkDefault false;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
