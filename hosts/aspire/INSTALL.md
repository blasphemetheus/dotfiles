# Installing NixOS on the Aspire (replacing Fedora)

Hardware as scanned from Fedora (2026-10-01): Ryzen 5 7520U, Radeon 610M (`amdgpu`),
MediaTek MT7921 WiFi (`mt7921e`), 1 TB NVMe, 1080p panel, touchscreen, battery `BAT1`,
s2idle-only suspend, Secure Boot already off. All of it works with the stock kernel.

## 0. Before wiping

- [ ] Copy anything you want off Fedora (`~/.ssh`, browser profile, documents). The disk gets erased.
- [ ] Know the WiFi password.
- [ ] On the desktop: the multi-host change is committed and pushed to GitHub.

## 1. Installer USB

The Ventoy stick (SanDisk, 233 GB) already carries `nixos-graphical-25.11…iso`; that is recent
enough — the installed system comes from this flake's lock, not from the ISO. Nothing to write.

## 2. Boot it

- [ ] Reboot, F2 for firmware setup; enable the F12 boot menu if it is off. Then F12 → USB →
      the NixOS entry in Ventoy (if it hangs, pick it again in "grub2 mode").
- [ ] Connect to WiFi, close the graphical installer window, open a terminal.

## 3. Partition (ERASES THE DISK)

The labels matter: the placeholder `hardware-configuration.nix` mounts by these labels.
The 20 GB swap is what makes hibernate possible (lid close → suspend → hibernate after 2 h).

```bash
sudo -i
parted /dev/nvme0n1 -- mklabel gpt
parted /dev/nvme0n1 -- mkpart ESP fat32 1MiB 1GiB
parted /dev/nvme0n1 -- set 1 esp on
parted /dev/nvme0n1 -- mkpart swap linux-swap 1GiB 21GiB
parted /dev/nvme0n1 -- mkpart root ext4 21GiB 100%
mkfs.fat -F 32 -n BOOT /dev/nvme0n1p1
mkswap -L swap /dev/nvme0n1p2
mkfs.ext4 -L nixos /dev/nvme0n1p3

mount /dev/disk/by-label/nixos /mnt
mount --mkdir -o umask=077 /dev/disk/by-label/BOOT /mnt/boot
swapon /dev/nvme0n1p2     # also gives the big source builds below room to spill
```

## 4. Get the config and the real hardware scan

The repo must live at `/home/blewf/dotfiles` — Home Manager symlinks `~/.config/hypr` etc.
straight into it.

```bash
mkdir -p /mnt/home/blewf
nix-shell -p git --run 'git clone https://github.com/blasphemetheus/dotfiles /mnt/home/blewf/dotfiles'
nixos-generate-config --root /mnt --show-hardware-config \
  > /mnt/home/blewf/dotfiles/hosts/aspire/hardware-configuration.nix
```

## 5. Install

```bash
nixos-install --root /mnt --flake /mnt/home/blewf/dotfiles#aspire
```

Expect a long compile (rough guess: an hour): Hyprland, its plugins and hyprdisplays have no
binary cache and build from source. It asks for a root password at the end.

**Do not reboot yet** — `blewf` has no password, and the session boots straight into the lock
screen:

```bash
nixos-enter --root /mnt -c 'passwd blewf'
nixos-enter --root /mnt -c 'chown -R blewf:users /home/blewf'
reboot
```

## 6. First boot

It autologins into Hyprland and immediately shows hyprlock; type the `blewf` password.
If that goes wrong: Ctrl+Alt+F2 for a TTY.

- [ ] WiFi: `nmtui` (or the nm-applet tray icon).
- [ ] GitHub access: `gh auth login`, then in `~/dotfiles`:
      `git remote set-url origin git@github.com:blasphemetheus/dotfiles.git`,
      commit the new `hosts/aspire/hardware-configuration.nix`, push.
- [ ] `~/.gitconfig` identity (name + email).
- [ ] `~/.config/fish/secrets.fish` — copy from the desktop (API keys).
- [ ] Coding agents (user profile, not in the flake):
      `nix profile install github:sadjow/claude-code-nix` and
      `nix profile install github:NixOS/nixpkgs/nixos-unstable#codex`
- [ ] Mail password: `secret-tool store --label="Migadu spikenard" email spikenard@ramblings.cc`
- [ ] `nix-index` once (powers `comma`), ~5–10 min.

## 7. Check these, tell Claude what's off

- [ ] Brightness keys, volume keys, battery % in waybar
- [ ] Touchpad (tap, two-finger scroll) and touchscreen
- [ ] Sound out of the speakers, and the internal mic
- [ ] Bluetooth
- [ ] Close the lid → suspends, wakes to the lock screen
- [ ] `systemctl hibernate` → powers off, resumes to the lock screen
- [ ] Dictation (F12) — tuned for the desktop's GPU, likely slow here
- [ ] Idle: screen off 15 min, lock 25, suspend 40 — same on battery as on AC

From then on: `git pull && nrs` on either machine.
