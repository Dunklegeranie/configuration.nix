# configuration.nix
# NixOS portátil en USB4 de 128 GB — entorno pentest básico, solo TTY.
# Prototipo: revisar ./hardware-configuration.nix antes de cualquier nixos-rebuild.

{ config, pkgs, lib, ... }:

{
  imports =
    [ ./hardware-configuration.nix              # Lenovo compacta (Core Ultra 9 + RTX) — por defecto
    # ./hardware-configuration-EXEMPLARIS.nix   # HP 15-da0026la real (i7-7500U + MX130): comenta la de arriba y descomenta esta
    ];

  ####################################################################
  # ARRANQUE (USB extraíble que se mueve entre equipos)
  ####################################################################

  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    device = "nodev";
    efiInstallAsRemovable = true;   # arranca en cualquier máquina sin tocarle la NVRAM al dueño
    useOSProber = false;
  };
  boot.loader.efi.canTouchEfiVariables = false;

  # kernel nuevo por las tarjetas wifi raras que uno se encuentra por ahí
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelModules = [ "kvm-intel" ];

  # módulos para que el USB levante en hardware variado (el resto va en hardware-configuration.nix)
  boot.initrd.availableKernelModules =
    [ "xhci_pci" "ehci_pci" "usb_storage" "uas" "sd_mod" "nvme" "ahci" ];

  boot.supportedFilesystems = [ "ntfs" "exfat" "ext4" "vfat" "btrfs" ];
  boot.tmp.cleanOnBoot = true;

  # 128 GB de USB, no pienso gastar una partición de swap en una memoria
  zramSwap.enable = true;
  zramSwap.memoryPercent = 50;

  ####################################################################
  # SISTEMA DE ARCHIVOS (ejemplo por etiqueta; lo real vive en hardware-configuration.nix)
  ####################################################################

  # fileSystems."/" = {
  #   device = "/dev/disk/by-label/NIXUSB";
  #   fsType = "ext4";
  #   options = [ "noatime" ];
  # };
  # fileSystems."/boot" = {
  #   device = "/dev/disk/by-label/BOOT";
  #   fsType = "vfat";
  # };

  ####################################################################
  # RED
  ####################################################################

  # el hostname va en ASCII (Æ no es válido), así que ÆTERNAM -> AETERNAM.
  # sí, es el mismo nombre de la NixOS de antes. el nombre vuelve.
  networking.hostName = "AETERNAM";
  networking.networkmanager.enable = true;

  # MAC aleatoria: el punto de un USB así es no dejar la misma huella en cada red
  networking.networkmanager.wifi.macAddress = "random";
  networking.networkmanager.ethernet.macAddress = "random";

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ ];          # nada escuchando por defecto
    allowedUDPPorts = [ ];
    # allowedTCPPorts = [ 22 ];     # abrir ssh solo cuando de verdad lo necesite
  };

  ####################################################################
  # LOCALE / CONSOLA (esto es puro TTY, no hay X ni Wayland)
  ####################################################################

  time.timeZone = "America/Managua";
  i18n.defaultLocale = "en_US.UTF-8";

  console = {
    keyMap = "la-latin1";   # teclado español latino
    font = "ter-v16n";      # terminus, se lee mejor a las 3am
    packages = [ pkgs.terminus_font ];
    # Catppuccin Mocha a mano, como siempre
    colors = [
      "1e1e2e" "f38ba8" "a6e3a1" "f9e2af"
      "89b4fa" "f5c2e7" "94e2d5" "bac2de"
      "585b70" "f38ba8" "a6e3a1" "f9e2af"
      "89b4fa" "f5c2e7" "94e2d5" "a6adc8"
    ];
  };

  ####################################################################
  # USUARIO
  ####################################################################

  users.users.Dunklegeranie = {
    isNormalUser = true;
    description = "Dunklegeranie";
    extraGroups = [ "wheel" "networkmanager" "wireshark" "audio" "dialout" "plugdev" ];
    shell = pkgs.zsh;
    # La contraseña NO está en este repo (es público). Se lee de un archivo con el
    # hash SHA-512 (openssl passwd -6) que hay que copiar al USB antes de instalar:
    #   /etc/nixos/secrets/dunklegeranie.hash  (root:root, chmod 600)
    # Si falta, el usuario queda sin contraseña y no se puede entrar.
    hashedPasswordFile = "/etc/nixos/secrets/dunklegeranie.hash";
  };
  security.sudo.wheelNeedsPassword = true;

  ####################################################################
  # SHELL, EDITOR Y TERMINAL
  ####################################################################

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
    histSize = 50000;
    ohMyZsh = {
      enable = true;
      # en TTY puro uno sin glifos raros; si la flecha se ve rota, cambiar a "gentoo"
      theme = "robbyrussell";
      plugins = [ "git" "sudo" "extract" "colored-man-pages" "history" ];
    };
  };

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
  };

  programs.tmux = {
    enable = true;
    clock24 = true;
    terminal = "tmux-256color";
    historyLimit = 50000;
  };

  programs.git.enable = true;
  programs.mtr.enable = true;

  # Alias propios: lo largo que se repite, acortado.
  environment.shellAliases = {
    # --- NixOS ---
    rebuild = "sudo nixos-rebuild switch";
    rebt    = "sudo nixos-rebuild test";          # probar sin dejarlo fijo
    upall   = "sudo nixos-rebuild switch --upgrade";
    conf    = "sudo $EDITOR /etc/nixos/configuration.nix";
    hwconf  = "sudo $EDITOR /etc/nixos/hardware-configuration.nix";
    ngc     = "sudo nix-collect-garbage -d";      # borrar generaciones viejas
    gens    = "sudo nix-env --list-generations --profile /nix/var/nix/profiles/system";
    nse     = "nix search nixpkgs";

    # --- shell / sistema ---
    rlp   = "exec zsh";                           # recargar la shell y con ella el PATH
    path  = "echo $PATH | tr ':' '\\n'";          # el PATH, una ruta por línea
    ports = "ss -tulpn";                          # qué está escuchando
    lip   = "ip -brief -color address";           # mis IPs locales
    myip  = "curl -s ifconfig.me";                # IP pública
    cl    = "clear";

    # --- listados (eza) ---
    ls = "eza --group-directories-first";
    ll = "eza -lah --group-directories-first --git";
    la = "eza -a --group-directories-first";
    lt = "eza --tree --level=2";
    b  = "bat";

    # --- pentest ---
    nsweep = "sudo nmap -sn";                     # hosts vivos en la red
    nscan  = "sudo nmap -sC -sV -T4";             # escaneo con scripts y versiones
    serve  = "python3 -m http.server";            # servidor HTTP al vuelo
    wl     = "cd /run/current-system/sw/share/wordlists";

    # --- música ---
    musica = "musikcube";
    sym    = "cd /home/Dunklegeranie/Symphonia/FLAC";
  };

  ####################################################################
  # PENTEST
  # (uso autorizado: labs, CTF y equipos propios o con permiso por escrito)
  ####################################################################

  # el módulo de wireshark da el grupo para capturar sin ser root;
  # en TTY uso tshark/termshark, no la GUI
  programs.wireshark = {
    enable = true;
    package = pkgs.wireshark-cli;
  };

  nixpkgs.config.allowUnfree = true;   # metasploit y compañía piden esto

  environment.systemPackages = with pkgs; [

    # --- recon / enumeración ---
    nmap
    masscan
    rustscan
    arp-scan
    fping
    whois
    traceroute
    dnsutils            # dig, nslookup, host
    dnsrecon
    amass
    subfinder
    theharvester
    nbtscan

    # --- web ---
    gobuster
    ffuf
    feroxbuster
    dirb
    nikto
    nuclei
    sqlmap
    wpscan
    whatweb
    httpie
    curl
    wget

    # --- captura / MITM / red ---
    tcpdump
    termshark           # TUI para leer pcaps, y se ve bien
    netcat-gnu
    socat
    bettercap
    ettercap
    mitmproxy
    proxychains-ng

    # --- wifi ---
    aircrack-ng
    reaverwps
    # kismet            # lo dejo comentado, pesa y casi nunca lo prendo

    # --- SMB / AD ---
    smbmap
    enum4linux-ng
    responder
    impacket
    netexec             # el antes llamado crackmapexec

    # --- credenciales / fuerza bruta (con permiso, obvio) ---
    thc-hydra
    john                # john the ripper
    hashcat
    hashcat-utils
    hashid
    seclists            # listas de palabras
    wordlists           # trae rockyou y amigos en /run/current-system/sw/share/wordlists

    # --- explotación / frameworks ---
    metasploit
    exploitdb           # searchsploit

    # --- forense / RE ligero ---
    binwalk
    foremost
    exiftool
    hexedit
    radare2

    # --- túneles / anonimato ---
    tor
    openvpn
    wireguard-tools

    # --- utilidades de terminal / TUI ---
    btop
    htop
    yazi                # gestor de archivos TUI
    fzf
    ripgrep
    fd
    bat
    eza
    tree
    ncdu
    jq
    lazygit
    unzip
    p7zip
    file

    # --- lenguajes de programación (orden UMBRAL) ---
    powershell          # PowerShell
    python3             # Python
    uv                  # entornos/paquetes de Python, rápido
    lua5_4              # Lua
    luajit
    luarocks
    ruby                # el mismo de los scripts de SketchUp
    nodejs              # JavaScript
    jdk                 # Java (OpenJDK)
    gcc                 # C
    gnumake
    gdb
    nasm                # ensamblador x86
    binutils            # ld / objdump, para armar el asm
    cargo               # Rust
    rustc
    clippy
    rustfmt
    rust-analyzer

    # --- música (musikcube + FLAC) ---
    musikcube           # reproductor + servidor, todo en TUI
    flac                # metaflac y el codec
    ffmpeg              # por si toca transcodificar algo
    beets               # etiquetar y ordenar la biblioteca; opcional pero útil
  ];

  ####################################################################
  # SERVICIOS
  ####################################################################

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.PermitRootLogin = "no";
    openFirewall = false;   # el puerto lo abro a mano cuando toca
  };

  # ... ¿en qué iba? ah sí, el audio. va aquí porque musikcube lo necesita.
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };
  security.rtkit.enable = true;

  ####################################################################
  # MÚSICA — biblioteca FLAC + musikcube (bloque "Symphonia" adaptado a Linux)
  ####################################################################

  # La carpeta local hace de Symphonia: aquí van los FLAC (copiados de S:\F.L.A.C).
  # Los paquetes (musikcube, flac, ffmpeg, beets) están arriba, en el grupo de música.
  # musikcube guarda su config por usuario, así que la ruta de la biblioteca
  # se añade a mano la primera vez (Settings -> directories). Esto solo deja el hueco listo.
  systemd.tmpfiles.rules = [
    "d /home/Dunklegeranie/Symphonia 0755 Dunklegeranie users - -"
    "d /home/Dunklegeranie/Symphonia/FLAC 0755 Dunklegeranie users - -"
  ];

  ####################################################################
  # NIX / MANTENIMIENTO
  ####################################################################

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.auto-optimise-store = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # documentación offline, que a veces no hay internet en el campo
  documentation.enable = true;
  documentation.man.enable = true;

  # TODO: averiguar por qué dejar esto en la versión vieja no rompe nada (no tocar)
  system.stateVersion = "25.05";
}
