#!/bin/bash
set -euo pipefail

# FERAL OS — PAW image build script
#
# Supports multiple hardware profiles. Select with --profile or FERAL_PROFILE env var.
# Default: rg35xxh
#
# Usage:
#   bash tools/build-paw-image.sh
#   bash tools/build-paw-image.sh --profile rg35xxh
#   FERAL_PROFILE=rg35xxh bash tools/build-paw-image.sh
#
# Optional env overrides:
#   FERAL_WORKSPACE   — build workspace dir (default: ~/feral-build)
#   FERAL_ROOTFS      — path to buildroot rootfs.tar (default: ~/buildroot/output/images/rootfs.tar)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

WORKSPACE="${FERAL_WORKSPACE:-$HOME/feral-build}"
BUILDROOT_ROOTFS="${FERAL_ROOTFS:-$HOME/buildroot/output/images/rootfs.tar}"

IMAGE_SIZE_MB=2048
BOOT_PART_SIZE_MB=128
IMAGE_NAME="feral-paw.img"

log()  { echo "[FERAL] $*"; }
warn() { echo "[WARN]  $*"; }
die()  { echo "[FAIL]  $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Hardware profiles
# To add a new target: add a case block below and a kernel config function.
# ---------------------------------------------------------------------------

PROFILE="${FERAL_PROFILE:-rg35xxh}"

# Parse --profile flag
while [[ $# -gt 0 ]]; do
    case "$1" in
        --profile) PROFILE="$2"; shift 2 ;;
        *) die "Unknown argument: $1" ;;
    esac
done

load_profile() {
    case "$PROFILE" in

        rg35xxh)
            # Anbernic RG35XX H — Allwinner H700, quad-core Cortex-A53 @ 1.5GHz
            # SoC family: H616. PMIC: AXP717. WiFi: RTL8821CS. GPU: Mali G31 MP2.
            # LCD: 3.5" 640x480 NV3052C. Two USB-C ports (OTG + host). UART on PCB.
            # FEL mode: connect OTG port (top USB-C) to PC with no SD card inserted.
            ARCH="arm64"
            CROSS_COMPILE="aarch64-linux-gnu-"
            UBOOT_REPO="https://github.com/u-boot/u-boot.git"
            KERNEL_REPO="https://git.sr.ht/~tokyovigilante/linux"
            KERNEL_BRANCH="h700-gpu-mainline"
            # h700-gpu-mainline carries WIP patches for H700 DE33 display engine,
            # NV3052C panel, Panfrost GPU power domain, and PWM backlight.
            UBOOT_DEFCONFIG_CANDIDATES=(
                anbernic_rg35xx_h700_defconfig
                anbernic_rg35xxplus_defconfig
                anbernic_rg35xx-h_defconfig
                rg35xx-h_defconfig
                anbernic-rg35xx-h_defconfig
                sun50i-h700-anbernic-rg35xxh_defconfig
            )
            DTB_NAME="sun50i-h700-anbernic-rg35xx-h.dtb"
            DTB_PATH="arch/arm64/boot/dts/allwinner/$DTB_NAME"
            OVERLAY_DIR="$REPO_ROOT/feral-os/overlays/paw"
            ;;

        *)
            die "Unknown profile: '$PROFILE'. Available profiles: rg35xxh"
            ;;
    esac
}

# ---------------------------------------------------------------------------
# Profile-specific kernel config functions
# Add one function per profile: kernel_configs_<profile>()
# These are applied on top of the common handheld configs.
# ---------------------------------------------------------------------------

kernel_configs_rg35xxh() {
    ./scripts/config \
        `# WiFi/BT: RTL8821CS (SDIO)` \
        --enable CONFIG_RTW88 \
        --enable CONFIG_RTW88_8821C \
        --enable CONFIG_RTW88_8821CS \
        `# PMIC: AXP717 via AXP20X driver` \
        --enable CONFIG_MFD_AXP20X \
        --enable CONFIG_MFD_AXP20X_I2C \
        --enable CONFIG_REGULATOR_AXP20X \
        --enable CONFIG_INPUT_AXP20X_PEK \
        --enable CONFIG_CHARGER_AXP20X \
        `# PMIC interrupts via sunxi NMI controller` \
        --enable CONFIG_SUNXI_NMI_INTC \
        `# Thumbsticks via H700 general purpose ADC` \
        --enable CONFIG_SUN20I_GPADC \
        `# RTC: BM8563 on PCB v4 (PCF8563-compatible)` \
        --enable CONFIG_RTC_DRV_PCF8563 \
        `# Display: H700 DE33 engine + NV3052C panel (WIP patches in kernel fork)` \
        --enable CONFIG_DRM_SUN4I \
        --enable CONFIG_DRM_PANEL_NEWVISION_NV3052C \
        `# PWM backlight (WIP patch in kernel fork)` \
        --enable CONFIG_PWM_SUN4I \
        `# GPU: Mali G31 MP2 via Panfrost (power domain patch in kernel fork)` \
        --enable CONFIG_DRM_PANFROST
}

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------

LOOP_DEV=""
cleanup() {
    if [[ -n "$LOOP_DEV" ]]; then
        sudo umount "$WORKSPACE/mnt/boot" 2>/dev/null || true
        sudo umount "$WORKSPACE/mnt/root" 2>/dev/null || true
        sudo losetup -d "$LOOP_DEV" 2>/dev/null || true
    fi
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Build steps
# ---------------------------------------------------------------------------

check_deps() {
    local apt_packages=(
        gcc-aarch64-linux-gnu
        make
        git
        parted
        dosfstools
        e2fsprogs
        util-linux
        xz-utils
        bison
        flex
        libssl-dev
        bc
        python3
        python3-setuptools
        swig
    )

    local missing_apt=()
    for pkg in "${apt_packages[@]}"; do
        dpkg -s "$pkg" &>/dev/null || missing_apt+=("$pkg")
    done

    if [[ ${#missing_apt[@]} -gt 0 ]]; then
        log "Installing missing packages: ${missing_apt[*]}"
        sudo apt-get update -qq
        sudo apt-get install -y "${missing_apt[@]}"
    fi

    command -v "${CROSS_COMPILE}gcc" &>/dev/null || \
        die "Cross-compiler ${CROSS_COMPILE}gcc still not found after install."

    [[ -f "$BUILDROOT_ROOTFS" ]] || \
        die "Buildroot rootfs not found at $BUILDROOT_ROOTFS. Set FERAL_ROOTFS to override."
}

build_atf() {
    log "[$PROFILE] Building ARM Trusted Firmware..."
    local atf_dir="$WORKSPACE/$PROFILE/trusted-firmware-a"

    if [[ ! -d "$atf_dir" ]]; then
        git clone --depth=1 https://git.trustedfirmware.org/TF-A/trusted-firmware-a.git "$atf_dir"
    fi

    cd "$atf_dir"
    make CROSS_COMPILE="$CROSS_COMPILE" PLAT=sun50i_h616 DEBUG=0 bl31
    [[ -f build/sun50i_h616/release/bl31.bin ]] || die "ATF bl31.bin not produced"
    log "ATF OK"
}

build_uboot() {
    log "[$PROFILE] Building U-Boot..."
    local uboot_dir="$WORKSPACE/$PROFILE/u-boot"

    if [[ ! -d "$uboot_dir" ]]; then
        git clone "$UBOOT_REPO" "$uboot_dir"
    fi

    # Build pylibfdt manually — setup.py cannot run in this context and
    # the PYMOD make step is unreliable with SWIG 4.3+.
    # We: patch the .i file, run swig, patch the generated .c, compile directly.
    local pylibfdt_dir="$uboot_dir/scripts/dtc/pylibfdt"
    local libfdt_dir="$uboot_dir/scripts/dtc/libfdt"

    log "Building pylibfdt..."

    # Patch .i_shipped for SWIG 4.3+ API compatibility
    sed -i 's/SWIG_Python_AppendOutput/SWIG_AppendOutput/g' "$pylibfdt_dir/libfdt.i_shipped"

    # Generate libfdt_wrap.c via swig
    cp "$pylibfdt_dir/libfdt.i_shipped" "$pylibfdt_dir/libfdt.i"
    swig -python -I"$uboot_dir/scripts/dtc" -I"$libfdt_dir" \
        -o "$pylibfdt_dir/libfdt_wrap.c" "$pylibfdt_dir/libfdt.i"

    # Patch generated C file for SWIG 4.3+ API compatibility
    sed -i 's/SWIG_Python_AppendOutput/SWIG_AppendOutput/g' "$pylibfdt_dir/libfdt_wrap.c"

    # Compile _libfdt.so directly, bypassing setup.py
    local pyinc
    pyinc=$(python3 -c "import sysconfig; print(sysconfig.get_path('include'))")
    local ext
    ext=$(python3 -c "import sysconfig; print(sysconfig.get_config_var('EXT_SUFFIX'))")

    gcc -shared -fPIC -o "$pylibfdt_dir/_libfdt${ext}" \
        -I"$pyinc" -I"$libfdt_dir" \
        "$pylibfdt_dir/libfdt_wrap.c" \
        "$libfdt_dir"/*.c

    [[ -f "$pylibfdt_dir/_libfdt${ext}" ]] || die "pylibfdt build failed"
    log "pylibfdt OK"

    # Add pylibfdt to PYTHONPATH so binman can find it
    export PYTHONPATH="$pylibfdt_dir:${PYTHONPATH:-}"

    cd "$uboot_dir"

    local defconfig=""
    for candidate in "${UBOOT_DEFCONFIG_CANDIDATES[@]}"; do
        if [[ -f "configs/$candidate" ]]; then
            defconfig="$candidate"
            break
        fi
    done

    if [[ -z "$defconfig" ]]; then
        warn "Could not find defconfig for profile '$PROFILE'. Candidates searched:"
        printf '  %s\n' "${UBOOT_DEFCONFIG_CANDIDATES[@]}"
        warn "Available configs matching profile hints:"
        find configs/ \( -name "*h700*" -o -name "*rg35*" -o -name "*anbernic*" \) | sort
        die "Identify the correct defconfig above and add it to the profile."
    fi

    log "U-Boot defconfig: $defconfig"
    make CROSS_COMPILE="$CROSS_COMPILE" "$defconfig"

    # The H700 defconfig uses the rg35xx-2024 device tree which is fine for U-Boot.
    # U-Boot only needs MMC and console — H-specific features are handled by the kernel DTS.

    # Override boot command to load kernel directly from FAT partition.
    # Try mmc 0 first, fall back to mmc 1 (RG35XX H has two SD slots).
    ./scripts/config --set-str CONFIG_BOOTCOMMAND \
        "if load mmc 0:1 \${kernel_addr_r} /Image; then load mmc 0:1 \${fdt_addr_r} /sun50i-h700-anbernic-rg35xx-h.dtb; setenv bootargs root=/dev/mmcblk0p2 rootwait console=ttyS0,115200; booti \${kernel_addr_r} - \${fdt_addr_r}; elif load mmc 1:1 \${kernel_addr_r} /Image; then load mmc 1:1 \${fdt_addr_r} /sun50i-h700-anbernic-rg35xx-h.dtb; setenv bootargs root=/dev/mmcblk1p2 rootwait console=ttyS0,115200; booti \${kernel_addr_r} - \${fdt_addr_r}; fi"

    make CROSS_COMPILE="$CROSS_COMPILE" olddefconfig
    make CROSS_COMPILE="$CROSS_COMPILE" BL31="$WORKSPACE/$PROFILE/trusted-firmware-a/build/sun50i_h616/release/bl31.bin" NO_PYTHON=1 -j"$(nproc)"

    [[ -f u-boot-sunxi-with-spl.bin ]] || die "U-Boot build produced no u-boot-sunxi-with-spl.bin"
    log "U-Boot OK"
}

build_kernel() {
    log "[$PROFILE] Building kernel (branch: ${KERNEL_BRANCH:-default})..."
    local kernel_dir="$WORKSPACE/$PROFILE/linux"

    if [[ ! -d "$kernel_dir" ]]; then
        local clone_args=(--depth=1)
        [[ -n "${KERNEL_BRANCH:-}" ]] && clone_args+=(--branch "$KERNEL_BRANCH")
        git clone "${clone_args[@]}" "$KERNEL_REPO" "$kernel_dir"
    fi

    cd "$kernel_dir"

    make ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" defconfig

    # Common configs for any Linux handheld target
    ./scripts/config \
        `# Input subsystem` \
        --enable CONFIG_INPUT \
        --enable CONFIG_INPUT_EVDEV \
        --enable CONFIG_INPUT_JOYSTICK \
        --enable CONFIG_INPUT_KEYBOARD \
        --enable CONFIG_INPUT_TOUCHSCREEN \
        `# HID` \
        --enable CONFIG_HID \
        --enable CONFIG_HID_GENERIC \
        --enable CONFIG_USB_HID \
        `# Bluetooth` \
        --enable CONFIG_BT \
        --enable CONFIG_BT_HCIBTUSB \
        --enable CONFIG_BT_HCIUART \
        `# Sound subsystem (SoC audio for embedded targets)` \
        --enable CONFIG_SOUND \
        --enable CONFIG_SND \
        --enable CONFIG_SND_SOC \
        `# DRM and backlight class (required by panel drivers)` \
        --enable CONFIG_DRM \
        --enable CONFIG_BACKLIGHT_CLASS_DEVICE \
        `# USB host and storage` \
        --enable CONFIG_USB \
        --enable CONFIG_USB_EHCI_HCD \
        --enable CONFIG_USB_STORAGE \
        `# Filesystems` \
        --enable CONFIG_VFAT_FS \
        --enable CONFIG_EXT4_FS \
        `# USB gadget serial — enables serial console over the OTG USB-C port` \
        --enable CONFIG_USB_GADGET \
        --enable CONFIG_USB_G_SERIAL \
        `# USB ethernet (generic, for debug adapters)` \
        --enable CONFIG_USB_NET_DRIVERS \
        --enable CONFIG_USB_RTL8152

    # Profile-specific configs
    "kernel_configs_$PROFILE"

    make ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" olddefconfig
    # Kernel build is memory-hungry. Cap at 4 jobs to avoid OOM in WSL2.
    local jobs
    jobs=$(( $(nproc) > 4 ? 4 : $(nproc) ))

    make ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" -j"$jobs" Image modules

    # Build only the device tree subtrees we actually need.
    # Add entries here when supporting new hardware targets.
    make ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" -j"$jobs" \
        allwinner/sun50i-h700-anbernic-rg35xx-h.dtb
        # allwinner/sun50i-h700-anbernic-rg35xx-plus.dtb   # RG35XX Plus
        # allwinner/sun50i-h616-orangepi-zero2.dtb          # example other H616 target

    [[ -f arch/arm64/boot/Image ]] || die "Kernel Image not produced"
    [[ -f "$DTB_PATH" ]] || die "Device tree not built: $DTB_PATH"
    log "Kernel OK"
}

assemble_image() {
    log "[$PROFILE] Assembling image..."
    local image="$WORKSPACE/$PROFILE/$IMAGE_NAME"

    dd if=/dev/zero of="$image" bs=1M count="$IMAGE_SIZE_MB" status=progress

    # Partition layout:
    #   1MiB gap for U-Boot SPL (written raw at 8KB offset, sunxi convention)
    #   p1: FAT32 boot — kernel Image, DTB, extlinux.conf
    #   p2: ext4 rootfs — Buildroot rootfs + kernel modules + overlays
    parted -s "$image" \
        mklabel msdos \
        mkpart primary fat32 1MiB $((1 + BOOT_PART_SIZE_MB))MiB \
        mkpart primary ext4 $((1 + BOOT_PART_SIZE_MB))MiB 100%

    dd if="$WORKSPACE/$PROFILE/u-boot/u-boot-sunxi-with-spl.bin" \
       of="$image" bs=1024 seek=8 conv=notrunc

    LOOP_DEV="$(sudo losetup -f --show -P "$image")"
    log "Loop device: $LOOP_DEV"

    sudo mkfs.fat -F 32 -n BOOT  "${LOOP_DEV}p1"
    sudo mkfs.ext4 -L rootfs     "${LOOP_DEV}p2"

    local boot_mnt="$WORKSPACE/mnt/boot"
    local root_mnt="$WORKSPACE/mnt/root"
    mkdir -p "$boot_mnt" "$root_mnt"

    sudo mount "${LOOP_DEV}p1" "$boot_mnt"
    sudo mount "${LOOP_DEV}p2" "$root_mnt"

    sudo cp "$WORKSPACE/$PROFILE/linux/arch/arm64/boot/Image" "$boot_mnt/"
    sudo cp "$WORKSPACE/$PROFILE/linux/$DTB_PATH" "$boot_mnt/"

    sudo mkdir -p "$boot_mnt/extlinux"
    sudo tee "$boot_mnt/extlinux/extlinux.conf" > /dev/null <<EOF
label FERAL PAW
  kernel /Image
  fdt /$DTB_NAME
  append root=/dev/mmcblk0p2 rootwait console=ttyS0,115200
EOF

    sudo make -C "$WORKSPACE/$PROFILE/linux" \
        ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" \
        INSTALL_MOD_PATH="$root_mnt" modules_install

    sudo tar -xf "$BUILDROOT_ROOTFS" -C "$root_mnt"

    if [[ -d "$OVERLAY_DIR" ]]; then
        sudo cp -r "$OVERLAY_DIR/." "$root_mnt/"
        # GitHub doesn't preserve execute bits — restore them for init scripts
        sudo chmod +x "$root_mnt/etc/init.d/"S* 2>/dev/null || true
        log "Overlays applied from $OVERLAY_DIR"
    else
        warn "No overlay dir at $OVERLAY_DIR — skipping."
    fi

    sync
    sudo umount "$boot_mnt" "$root_mnt"
    sudo losetup -d "$LOOP_DEV"
    LOOP_DEV=""

    log "Image ready: $image"
    log "Flash with:  sudo dd if=$image of=/dev/sdX bs=4M status=progress && sync"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
    load_profile
    log "Profile: $PROFILE"
    mkdir -p "$WORKSPACE/$PROFILE"
    check_deps
    build_atf
    build_uboot
    build_kernel
    assemble_image
    log "Done."
}

main
