# hardware-configuration-EXEMPLARIS.nix
# Variante de hardware para el hardware REAL: HP 15-da0026la (la máquina EXEMPLARIS).
#   CPU Intel Core i7-7500U (Kaby Lake, 7ª gen) · iGPU Intel HD 620
#   dGPU NVIDIA GeForce MX130 (Maxwell, 2 GB) en Optimus
#   SSD SATA W800S + HDD Toshiba MQ01ABF050 (controladora Intel RST)
#
# El USB sigue siendo el mismo (arranca por etiqueta NIXUSB/BOOT); esto solo cambia
# lo que depende de la MÁQUINA en la que lo enchufas.
#
# USO: en configuration.nix, en imports, deja esta en vez de ./hardware-configuration.nix
#      (ver el comentario de allí). Lo ideal sigue siendo regenerar con
#      `nixos-generate-config` sobre la propia HP para los UUID reales.
#
# OJO: dos bloques van marcados como COMENTABLES (USB y NVIDIA). Son los dos puntos
# donde más se rompe un arranque; si algo falla, los comentas y la HP sigue arrancando.

{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  ####################################################################
  # ┌─ BLOQUE USB (COMENTABLE) ──────────────────────────────────────
  # │ Módulos para arrancar el USB en la HP y para ver sus discos SATA.
  # │ Las líneas de ARRANCAR el USB no las comentes salvo diagnóstico:
  # │ sin ellas el USB no levanta (el root vive en él).
  # │ La línea dudosa es `uas`: con algunos puentes USB-SATA se cuelga
  # │ en el arranque. Si el USB no levanta, COMENTA "uas" y reconstruye:
  # │ caerá a "usb_storage", más lento pero fiable.
  ####################################################################

  boot.initrd.availableKernelModules = [
    # --- arrancar desde el USB (no comentar) ---
    "xhci_pci"        # USB 3.x (puertos azules de la HP)
    "ehci_pci"        # USB 2.0 (si enchufas el USB en un puerto negro)
    "usb_storage"
    "uas"             # <-- COMENTABLE: déjalo fuera si el USB no arranca
    "sd_mod"
    # --- discos INTERNOS SATA de la HP (SSD W800S + HDD Toshiba) ---
    "ahci"
    "ata_piix"        # fallback por si la controladora cae a modo legacy
    # "nvme"          # la HP NO tiene NVMe; eso es de la versión Lenovo
  ];

  # └────────────────────────────────────────────────────────────────

  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  # i7-7500U = Intel, microcódigo al día
  hardware.cpu.intel.updateMicrocode =
    lib.mkDefault config.hardware.enableRedistributableFirmware;
  hardware.enableRedistributableFirmware = true;

  ####################################################################
  # SISTEMA DE ARCHIVOS (el mismo USB, por etiqueta)
  #   al formatear:  mkfs.ext4 -L NIXUSB   y   mkfs.fat -F32 -n BOOT
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

  # --- (opcional) montar un disco INTERNO de la HP para leer sus datos ---
  # Descomenta y ajusta la etiqueta/UUID si quieres llegar a P: (Pratum) o C:.
  # Los discos de la HP son NTFS; boot.supportedFilesystems ya trae "ntfs".
  #   fileSystems."/mnt/pratum" = {
  #     device = "/dev/disk/by-label/Pratum";
  #     fsType = "ntfs3";
  #     options = [ "noauto" "x-systemd.automount" "uid=1000" "gid=100" ];
  #   };
  # NOTA (Intel RST): si en la BIOS de la HP el SATA está en modo "Intel RST /
  # Optane" y no en AHCI, Linux puede NO ver el SSD ni el HDD. Es ajuste de BIOS,
  # no de este archivo: pásalo a AHCI (ojo, Windows pide arrancar una vez en modo
  # seguro tras el cambio) o deja la lectura de esos discos para otro momento.

  ####################################################################
  # ┌─ BLOQUE NVIDIA — MX130 (COMENTABLE) ───────────────────────────
  # │ Seguimos en TTY: la pantalla la mueve la iGPU Intel HD 620 (i915,
  # │ sin tocar nada). Esto NO es para escritorio: es para que hashcat
  # │ tire de la MX130 por CUDA. La MX130 es Maxwell, así que va el
  # │ driver LEGACY 470 y `open = false` (los módulos abiertos son
  # │ Turing+; en Maxwell no sirven).
  # │
  # │ SI FALLA (el rebuild no compila el driver, o el TTY no aparece):
  # │ comenta este bloque ENTERO (las 3 declaraciones de abajo) y
  # │ reconstruye. La HP arrancará solo con la Intel; pierdes CUDA en
  # │ la MX130, pero arranca.
  ####################################################################

  # instala el driver NVIDIA aunque X nunca arranque (xserver.enable sigue en false)
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.graphics.enable = true;

  hardware.nvidia = {
    open = false;                # Maxwell: módulos cerrados, SÍ o SÍ
    modesetting.enable = true;   # si el TTY se queda en negro, prueba a ponerlo en false
    nvidiaSettings = false;      # no hay GUI que configurar
    powerManagement.enable = false;
    package = config.boot.kernelPackages.nvidiaPackages.legacy_470;
  };

  # El legacy_470 NO compila contra kernels muy nuevos (y configuration.nix usa
  # linuxPackages_latest por las wifi raras). Si el rebuild falla compilando el
  # driver, DESCOMENTA la línea siguiente para fijar un kernel LTS compatible:
  # boot.kernelPackages = lib.mkForce pkgs.linuxPackages;

  # hashcat + CUDA en Maxwell (compute 5.0): si lo activas, puede pedir una versión
  # concreta de CUDA. Déjalo comentado hasta que el driver cargue; de mientras,
  # hashcat tira de OpenCL sin esto.
  # nixpkgs.config.cudaSupport = true;

  # └────────────────────────────────────────────────────────────────

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
