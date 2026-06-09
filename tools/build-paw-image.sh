#!/bin/bash
# FERAL OS PAW image builder
# Builds a flashable SD card image for the Anbernic RG35XX H (Allwinner H700)
#
# Usage: ./build-paw-image.sh <rootfs.tar> <output.img>
#
# Requirements:
#   sudo apt install squashfs-tools dosfstools parted
#
# Licence: MIT

set -e

ROOTFS_TAR="${1:-rootfs.tar}"
OUTPUT_IMG="${2:-feral-paw.img}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BLOBS_DIR="$SCRIPT_DIR/../feral-os/blobs/h700"
OVERLAY_DIR="$SCRIPT_DIR/../feral-os/overlays/paw"
WORK_DIR="$(mktemp -d)"

cleanup() {
    echo "Cleaning up..."
    sudo umount "$WORK_DIR/fat_mount" 2>/dev/null || true
    sudo losetup -d "$LOOP" 2>/dev/null || true
    sudo rm -rf "$WORK_DIR"
}
trap cleanup EXIT

echo "=== FERAL OS PAW image builder ==="
echo ""

# Validate inputs
if [ ! -f "$ROOTFS_TAR" ]; then
    echo "ERROR: rootfs tarball not found: $ROOTFS_TAR"
    exit 1
fi

if [ ! -d "$BLOBS_DIR" ]; then
    echo "ERROR: blobs directory not found: $BLOBS_DIR"
    exit 1
fi

for blob in boot0.img boot_package.fex boot.img env.img; do
    if [ ! -f "$BLOBS_DIR/$blob" ]; then
        echo "ERROR: missing blob: $BLOBS_DIR/$blob"
        exit 1
    fi
done

echo "Inputs OK"
echo "  rootfs:  $ROOTFS_TAR"
echo "  blobs:   $BLOBS_DIR"
echo "  overlay: $OVERLAY_DIR"
echo "  output:  $OUTPUT_IMG"
echo ""

IMAGE_SIZE_MB=7800

echo "Step 1/7: Creating blank image (${IMAGE_SIZE_MB}MB)..."
dd if=/dev/zero of="$OUTPUT_IMG" bs=1M count=$IMAGE_SIZE_MB status=progress

echo ""
echo "Step 2/7: Writing boot blobs at raw offsets..."
dd if="$BLOBS_DIR/boot0.img"        of="$OUTPUT_IMG" bs=512 seek=512      conv=notrunc
dd if="$BLOBS_DIR/boot_package.fex" of="$OUTPUT_IMG" bs=512 seek=32800    conv=notrunc
dd if="$BLOBS_DIR/boot.img"         of="$OUTPUT_IMG" bs=512 seek=73728    conv=notrunc
dd if="$BLOBS_DIR/env.img"          of="$OUTPUT_IMG" bs=512 seek=131072   conv=notrunc

echo ""
echo "Step 3/7: Writing GPT partition table..."
parted -s "$OUTPUT_IMG" mklabel gpt
parted -s "$OUTPUT_IMG" mkpart primary 37748736B 58720255B
parted -s "$OUTPUT_IMG" mkpart primary 58720256B 75497471B
parted -s "$OUTPUT_IMG" mkpart primary fat32 75497472B 5435817983B
parted -s "$OUTPUT_IMG" mkpart primary 5435817984B 100%

echo ""
echo "Step 4/7: Formatting FAT32 boot partition..."
LOOP=$(sudo losetup -f --show -P "$OUTPUT_IMG")
sudo mkfs.vfat -F 32 -n "BATOCERA" "${LOOP}p3"

echo ""
echo "Step 5/7: Building squashfs rootfs..."
mkdir -p "$WORK_DIR/rootfs"
sudo tar -xf "$ROOTFS_TAR" -C "$WORK_DIR/rootfs"

# Apply PAW overlay
if [ -d "$OVERLAY_DIR" ]; then
    echo "  Applying PAW overlay from $OVERLAY_DIR"
    sudo cp -r "$OVERLAY_DIR"/. "$WORK_DIR/rootfs/"
else
    echo "  No overlay found at $OVERLAY_DIR, skipping"
fi

# Add required directories
sudo mkdir -p "$WORK_DIR/rootfs/boot"
sudo mkdir -p "$WORK_DIR/rootfs/overlay"

# Add /init symlink for initramfs compatibility
sudo ln -sf /sbin/init "$WORK_DIR/rootfs/init"

# Copy kernel modules if they exist
MODULES_DIR="$BLOBS_DIR/modules"
if [ -d "$MODULES_DIR" ]; then
    echo "  Adding kernel modules from $MODULES_DIR"
    sudo cp -r "$MODULES_DIR" "$WORK_DIR/rootfs/lib/"
else
    echo "  WARNING: No kernel modules found at $MODULES_DIR"
    echo "  WiFi and display will not work without modules."
fi

sudo mksquashfs "$WORK_DIR/rootfs" "$WORK_DIR/feral.squashfs" -comp gzip -noappend

echo ""
echo "Step 6/7: Populating FAT32 partition..."
mkdir -p "$WORK_DIR/fat_mount"
sudo mount "${LOOP}p3" "$WORK_DIR/fat_mount"

sudo mkdir -p "$WORK_DIR/fat_mount/boot"
sudo mkdir -p "$WORK_DIR/fat_mount/partitions"

sudo cp "$WORK_DIR/feral.squashfs" "$WORK_DIR/fat_mount/boot/batocera"

echo "rg35xx-h" | sudo tee "$WORK_DIR/fat_mount/boot/batocera.board" > /dev/null
echo "rg35xx-h bluetooth rumble adb analogstick wifi hdmi" | sudo tee "$WORK_DIR/fat_mount/boot/batocera.board.capability" > /dev/null
sudo touch "$WORK_DIR/fat_mount/boot/autoresize"

sudo cp "$BLOBS_DIR/boot_package.cfg" "$WORK_DIR/fat_mount/partitions/" 2>/dev/null || true
sudo cp "$BLOBS_DIR/boot_package.fex" "$WORK_DIR/fat_mount/partitions/"
sudo cp "$BLOBS_DIR/boot.img"         "$WORK_DIR/fat_mount/partitions/"
sudo cp "$BLOBS_DIR/boot0.img"        "$WORK_DIR/fat_mount/partitions/"
sudo cp "$BLOBS_DIR/env.img"          "$WORK_DIR/fat_mount/partitions/"

cat << 'EOF' | sudo tee "$WORK_DIR/fat_mount/batocera-boot.conf" > /dev/null
sharedevice=INTERNAL
system.hostname=feral-paw
EOF

sudo umount "$WORK_DIR/fat_mount"

echo ""
echo "Step 7/7: Detaching loop device..."
sudo losetup -d "$LOOP"
LOOP=""

echo ""
echo "=== Build complete ==="
echo "Output: $OUTPUT_IMG"
echo ""
echo "Flash with:"
echo "  sudo dd if=$OUTPUT_IMG of=/dev/sdX bs=4M status=progress"
