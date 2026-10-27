# configuration.nix

Configuraciones de NixOS de Dunklegeranie.

## aeternam/ — ÆTERNAM

NixOS portátil en USB para pentest, solo TTY. Un `configuration.nix` común y una variante de hardware por máquina:

- `hardware-configuration.nix`: Lenovo compacta (Core Ultra 9 + RTX). Es la que se importa por defecto.
- `hardware-configuration-EXEMPLARIS.nix`: HP 15-da0026la (i7-7500U + MX130, `legacy_470`).

La máquina se elige comentando o descomentando una línea del `imports` en `configuration.nix`.

### Contraseña

El repo es público, así que la contraseña no está aquí. El usuario usa `hashedPasswordFile`, y el archivo con el hash se copia a mano antes de instalar:

```bash
sudo mkdir -p /mnt/etc/nixos/secrets
sudo cp dunklegeranie.hash /mnt/etc/nixos/secrets/
sudo chmod 600 /mnt/etc/nixos/secrets/dunklegeranie.hash
```

Para generar un hash nuevo: `openssl passwd -6`.

### Instalar en el USB

```bash
sudo mkfs.ext4 -L NIXUSB /dev/sdX2
sudo mkfs.fat -F32 -n BOOT /dev/sdX1
sudo mount /dev/disk/by-label/NIXUSB /mnt
sudo mkdir -p /mnt/boot && sudo mount /dev/disk/by-label/BOOT /mnt/boot
sudo mkdir -p /mnt/etc/nixos
sudo cp aeternam/*.nix /mnt/etc/nixos/
# copiar el hash (ver arriba)
sudo nixos-install
```
