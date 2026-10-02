# Raspberry Pi 4B Image Builder

A basic automation pipeline for headless Raspberry Pi 4 Model B deployment.

## Project Purpose

This set of scripts generates a modified, headless **Ubuntu Server 24.04 (arm64)**
boot image for the Raspberry Pi 4B. It downloads Canonical's official preinstalled
server image, loop-mounts it on an x86 host, and provisions it via a QEMU-based
`aarch64` chroot — creating a user, injecting SSH keys, and configuring Zsh — then
seals the result into a flashable image.

> Migrated from an NVIDIA Jetson (L4T) pipeline. The Jetson-specific BSP download,
> `apply_binaries`, and `jetson-disk-image-creator` packaging have been replaced by
> a download → loop-mount → chroot → reseal flow appropriate for the Pi.

## Platform Requirement (Build Host)

- Generic Ubuntu 22.04/24.04 host (x86/64), WSL2 supported
- `sudo` privileges (loop mounts + chroot)
- Packages: `qemu-user-static`, `binfmt-support`, `xz-utils`, `parted`, `e2fsprogs`, `wget`
  ```bash
  sudo apt-get install -y qemu-user-static binfmt-support xz-utils parted e2fsprogs wget
  ```
- Minimum ~15 GB free disk space

## Usage Guide

1. **Define users:** copy `config/users.csv.example` to `config/users.csv` and edit it
   (see [Configuration](#configuration)). Place the SSH public key material referenced
   by that CSV into `keys/` (e.g. an `authorized_keys` file and/or `*.pub` files).
2. **(Optional) Configure networking:** copy `config/network.conf.example` to
   `config/network.conf` for Wi-Fi and/or static IPs. Skip for plain DHCP.
3. Run the scripts in order (**00 → 06**). Steps 04–06 require `sudo`.
   (If `config/users.csv`/`config/network.conf` are missing, step 03 auto-creates them
   from the templates.)
4. Flash the resulting `raspi4b_headless.img.xz` to a MicroSD card (Raspberry Pi
   Imager / BalenaEtcher), or:
   ```bash
   xzcat raspi4b_headless.img.xz | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
   ```
5. Boot the Pi, then `ssh <user>@raspberrypi.local` (first CSV user is `pi`/`pi`).

| Script | Name | Description |
| :--- | :--- | :--- |
| **00** | `00_build_zsh_plugins.sh` | Fetches Zsh plugins into the host staging area. |
| **01** | `01_download_base_image.sh` | Downloads the Ubuntu Server Pi image and verifies its SHA256. |
| **02** | `02_extract_image.sh` | Decompresses the image and adds slack space for installs. |
| **03** | `03_stage_payload.sh` | Stages `users.csv`, `network.conf`, and SSH keys into the provisioning payload. |
| **04** | `04_mount_image.sh` | Loop-mounts the image, grows the rootfs, overlays modifications *(sudo)*. |
| **05** | `05_provision_image.sh` | Runs the in-chroot provisioning hook via QEMU *(sudo)*. |
| **06** | `06_package_image.sh` | Unmounts, detaches the loop device, and compresses the final image *(sudo)*. |
| **07** | `07_interactive_mount.sh` | Standalone: drops into an interactive chroot for manual tweaks *(sudo)*. |

## Configuration

All customization lives in the `config/` directory. The real files
(`config/users.csv`, `config/network.conf`) are git-ignored because they hold
passwords / Wi-Fi secrets; commit only the `.example` templates.

### `config/users.csv` — users, passwords, groups, shells, keys

One row per user. Columns:

| Column | Meaning |
| :--- | :--- |
| `username` | Login name (no spaces). |
| `password` | Plaintext password, applied by `05_set_password.sh`. **Blank ⇒ account locked** (SSH-key login only). |
| `groups` | `;`-separated extra groups; include `sudo` for admin. Groups absent on the base image are skipped. |
| `shell` | `zsh` (default) or `bash`. |
| `ssh_keys` | `;`-separated key filenames in `keys/`; their contents are appended to that user's `authorized_keys`. |

```csv
username,password,groups,shell,ssh_keys
pi,pi,sudo;dialout;video,zsh,authorized_keys
alice,s3cret,sudo,bash,alice.pub
bob,,,,bob.pub          # no password -> key-only login
```

> Do not put spaces around commas or commas inside a field.

### `config/network.conf` — Wi-Fi & static IPs

Sourced as shell variables by `06_network_config.sh`, which writes
`/etc/netplan/99-harness.yaml`. If Wi-Fi and both static IPs are left blank, the
image keeps its default cloud-init DHCP (nothing is changed). When any value is
set, cloud-init's network management is disabled so the generated netplan is
authoritative.

- **Wi-Fi:** set `WIFI_SSID`, `WIFI_PASSWORD`, `WIFI_COUNTRY` (installs `wpasupplicant`).
- **Ethernet static IP:** set `ETH_STATIC_IP` (CIDR, e.g. `192.168.1.50/24`), `ETH_GATEWAY`, `ETH_DNS`.
- **Wi-Fi static IP:** set `WIFI_STATIC_IP`, `WIFI_GATEWAY`, `WIFI_DNS`.
- Leaving a static-IP field blank uses DHCP on that interface.

## Catalog — What Gets Installed / Changed

Everything below is applied to the base **Ubuntu Server 24.04 arm64** image. Nothing
else is added; ROS 2 and desktop tooling from the original Jetson pipeline are **not**
included.

### Packages installed (via `apt-get` inside the chroot)
| Package | Source script | Why |
| :--- | :--- | :--- |
| `zsh` | `03_setup_zsh.sh` | Interactive shell + default shell for users. |
| `openssh-server` | `04_headless_config.sh` | Ensures headless SSH access (usually already present). |
| `wpasupplicant` | `06_network_config.sh` | **Only if Wi-Fi is configured** in `network.conf`. |

### Files added to the image
| Path | Purpose |
| :--- | :--- |
| `/usr/share/zsh-plugins/zsh-autosuggestions` | Zsh plugin (git clone, host step 00). |
| `/usr/share/zsh-plugins/zsh-syntax-highlighting` | Zsh plugin. |
| `/usr/share/zsh-plugins/zsh-autocomplete` | Zsh plugin. |
| `/etc/skel/.zshrc` | Default Zsh config (prompt, history, plugin loader). |
| `/home/<user>/.zshrc` | Copied from skel for each zsh user. |
| `/home/<user>/.ssh/authorized_keys` | Per-user keys assembled from the CSV `ssh_keys` column. |
| `/etc/cloud/cloud.cfg.d/99_pi_harness.cfg` | Suppresses cloud-init's default `ubuntu` user; preserves hostname. |
| `/etc/netplan/99-harness.yaml` | **Only if** Wi-Fi/static IP is configured. Generated network config. |
| `/etc/cloud/cloud.cfg.d/99-disable-network-config.cfg` | **Only if** custom networking is configured — hands netplan authority. |
| `/opt/provisioning/*` | Provisioning scripts + staged `users.csv`/keys — **deleted at the end of provisioning.** |

### System changes
| Change | Source script |
| :--- | :--- |
| **Every user in `config/users.csv`** created, added to their listed groups (only groups that exist). | `01_create_user.sh` |
| Per-user SSH `authorized_keys` assembled from the CSV `ssh_keys` column. | `02_setup_keys.sh` |
| Per-user login shell set (`zsh` default, or `bash`) per the CSV `shell` column. | `03_setup_zsh.sh` |
| Default systemd target set to `multi-user.target` (no display manager). | `04_headless_config.sh` |
| SSH service enabled at boot. | `04_headless_config.sh` |
| Hostname set to `raspberrypi`; `/etc/hosts` updated. | `04_headless_config.sh` |
| cloud-init default user disabled (network config left intact unless overridden). | `04_headless_config.sh` |
| **Per-user passwords set from the CSV** (blank ⇒ account locked). | `05_set_password.sh` |
| Netplan Wi-Fi/static-IP config written; cloud-init networking disabled. **Only if configured.** | `06_network_config.sh` |

### Cleanup performed
- `/opt/provisioning/` (scripts, staged keys, `users.csv`, `network.conf`) is removed after provisioning.
- The `qemu-aarch64-static` shim is removed from the image before sealing.

## Configuration Points

- **Users / passwords / groups / shells / keys:** `config/users.csv` (see [Configuration](#configuration)).
- **Wi-Fi / static IPs:** `config/network.conf`.
- **Ubuntu point release:** `UBUNTU_POINT` in `01_download_base_image.sh` / `02_extract_image.sh`.
- **Slack space for installs:** `EXPAND_MB` in `02_extract_image.sh` (default 2048 MiB).
- **Skip compression:** run `COMPRESS=0 ./06_package_image.sh`.

## Troubleshooting

- **Stuck mounts / "device is busy":** if a build aborts mid-way, run
  `06_package_image.sh` to unmount and detach, or clean up manually and delete
  `.build_state`.
- **`qemu-aarch64-static not found`:** install `qemu-user-static` + `binfmt-support`.
- **WSL:** if you see `sudo: unable to allocate pty`, run `wsl --shutdown` in
  PowerShell to reset the environment and clear stuck mounts.
