# Hardware Upgrade Plan — PowerSpec G914

## Current System (as of 2026-03-16)

| Component | Model | Details |
|---|---|---|
| CPU | AMD Ryzen 9 9950X3D | 16C/32T, 5.75GHz boost, AM5 |
| GPU | NVIDIA GeForce RTX 5090 | 32GB GDDR7, SM 12.0a (Blackwell) |
| Motherboard | MSI MAG X870E Tomahawk WiFi | ATX, AM5, DDR5, PCIe 5.0 |
| RAM | 64GB DDR5-6000 (2x32GB) | Team Group "UD5-6000", dual rank, slots A2+B2 occupied, A1+B1 empty |
| Storage | 1x 2TB Crucial P510 NVMe | 1 of 4 M.2 slots used |
| Cooling | 360mm AIO Liquid Cooler | |
| OS | NixOS (Linux 6.12.74) | |

## Motherboard Slot Availability

### RAM (DDR5 DIMM)
- **4 slots total**, 2 occupied (A2, B2), 2 free (A1, B1)
- Max supported: **256GB** (requires BIOS update — see below)
- Current BIOS v2.A02 (2025-07-30) reports 128GB max
- **BIOS v2.AA0 (2026-01-30)** adds AGESA 1.2.0.3C with 4x64GB / 256GB support
- **UPDATE BIOS BEFORE BUYING RAM** — download from https://www.msi.com/Motherboard/MAG-X870E-TOMAHAWK-WIFI/support
- Current sticks: Team Group "UD5-6000", 32GB dual-rank, DDR5-6000, 1.1V
- DDR5 Memory Boost up to 8400+ MT/s (OC) with AMD EXPO
- **Important:** AM5 memory controller runs 2 DIMMs better than 4. Running 4 sticks typically requires dropping speed (e.g., DDR5-6000 → DDR5-5600)

### M.2 NVMe
- **4 slots total**, 1 occupied, 3 free
  - 2x M.2 Gen5 x4 (128 Gbps)
  - 2x M.2 Gen4 x4 (64 Gbps)
- Note: USB4 ports share bandwidth with the second Gen5 slot (drops to Gen5 x2 when USB4 in use)

## Why Upgrade

### RAM
- Hit 99% RAM during concurrent Rust compilation (zed-editor) + XLA from-source build
- XLA Bazel builds with CUDA are memory-hungry (31GB cache, parallel compilation)
- ML/XLA compilation benefits from more RAM for Bazel's action parallelism
- 128GB is the sweet spot: enough headroom without the 4-DIMM speed penalty

### Storage
- Current disk: 590GB partition, 169GB used, 391GB free (31% usage)
- Nix store alone is 98GB and grows over time
- Bazel cache: 31GB and growing with from-source XLA builds
- A dedicated cache/scratch drive keeps the root partition clean

## Shopping List

### RAM: 2x64GB DDR5-6000 (replaces existing 2x32GB)

Using 2x64GB instead of 4x32GB because:
- AM5's memory controller handles 2 DIMMs at full speed
- 4 DIMMs typically requires dropping to DDR5-5600 or lower
- 2x64GB at DDR5-6000 CL30 = best bandwidth without compromise

| Option | Kit | Speed | Latency | ~Price |
|---|---|---|---|---|
| **Pick** | G.Skill Trident Z5 Neo 2x64GB (AMD EXPO) | DDR5-6000 | CL30 | ~$370 |
| Alt | Kingston Fury Beast 2x64GB (AMD EXPO) | DDR5-6000 | CL30 | ~$350 |

**Must have AMD EXPO profile** — Intel XMP kits may not run at rated speed on AM5.

### Storage: 2TB Gen4 NVMe (add to free M.2 Gen4 slot)

| Option | Drive | Interface | Read/Write | ~Price |
|---|---|---|---|---|
| **Pick** | WD Black SN770 2TB | Gen4 x4 | 5150/4850 MB/s | ~$120 |
| Alt | Samsung 990 EVO 2TB | Gen4 x4 | 5000/4200 MB/s | ~$130 |

Install in one of the **Gen4** M.2 slots (save Gen5 slots for future high-performance drives).

Suggested mount: `/mnt/cache` or bind-mount `~/.cache` to it to keep build artifacts off the root partition.

### Total

| Item | ~Price |
|---|---|
| G.Skill Trident Z5 Neo 2x64GB DDR5-6000 | ~$370 |
| WD Black SN770 2TB NVMe | ~$120 |
| **Total** | **~$490** |

## After Installation

### RAM
- Remove existing 2x32GB sticks
- Install 2x64GB in the same slots (A2/B2 — check motherboard manual)
- Enter BIOS, enable AMD EXPO profile for DDR5-6000
- Verify with `cat /proc/meminfo | grep MemTotal` (should show ~128GB)

### Storage
- Install NVMe in a Gen4 M.2 slot (M2_3 or M2_4 on this board)
- Format: `mkfs.ext4 /dev/nvme1n1p1` (or btrfs/xfs)
- Add to `/etc/nixos/hardware-configuration.nix` as a mount
- Optional: move `~/.cache` to the new drive via bind mount in `configuration.nix`:
  ```nix
  fileSystems."/home/blewf/.cache" = {
    device = "/dev/disk/by-uuid/<uuid>";
    fsType = "ext4";
  };
  ```
