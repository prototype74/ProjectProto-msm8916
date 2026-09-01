#!/sbin/sh
#
# Copyright (c) 2025-2026 prototype74
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

source /tmp/scripts/helpers.sh  # import helpers script

readonly NAME="repartitioner_lite"
progress=""

# Update ongoing progress bar in TWRP's GUI
_updateProgress() {
    local output_fd_path="$1"

    if [ -p "$output_fd_path" ] && [ -n "$progress" ]; then
        progress=$(awk -v p="$progress" 'BEGIN { printf "%.2f", p + 0.08 }')
        echo "set_progress $progress" > "$output_fd_path"
    fi
}

# Repartition microSD card to add vendor:
# - Partition 1 (external): uses all space except last 700 MiB
# - Partition 2 (vendor): 700 MiB at the end of the disk
repartitionMicroSdCardLite() {
    local output_fd_path="$1"
    local progress_start="$2"
    local total_sectors sector_size last_usable_sector
    local vendor_sector_size vendor_start_sector
    local external_end_sector

    if ! microSdCardAvailable; then
        echo "$NAME: microSD card not found: $DEV_BLOCK_MICROSD" >&2
        return 1
    fi

    total_sectors=$(blockdev --getsz "$DEV_BLOCK_MICROSD") || {
        echo "$NAME: failed to get total sector size from microSD!" >&2
        return 1
    }

    # sector size is usually 512 bytes
    sector_size=$(blockdev --getss "$DEV_BLOCK_MICROSD") || {
        echo "$NAME: failed to get sector size from microSD!" >&2
        return 1
    }

    # Last 34 sectors are reserved for GPT backup
    last_usable_sector=$((total_sectors - 34))

    vendor_sector_size=$((VENDOR_SIZE_BYTES / sector_size))
    # Align vendor start sector to 2048-sector boundary
    vendor_start_sector=$(( (last_usable_sector - vendor_sector_size + 1) / 2048 * 2048 ))
    external_end_sector=$((vendor_start_sector - 1))

    echo "$NAME: repartitioning microSD card started!"

    if checkFloat "$NAME" "progress_start" "$progress_start"; then
        progress="$progress_start"
    fi

    echo "$NAME: wiping existing partition table"
    sgdisk --mbrtogpt --clear "$DEV_BLOCK_MICROSD" || {
        echo "$NAME: failed to wipe partition table!" >&2
        return 1
    }
    _updateProgress "$output_fd_path"

    sleep 1

    echo "$NAME: creating new partitions"

    # Start at sector 2048 (standard alignment) and end before vendor
    sgdisk --new="1:2048:${external_end_sector}" \
        --change-name="1:external" \
        --typecode="1:0700" \
        "$DEV_BLOCK_MICROSD" || {
        echo "$NAME: FATAL: failed to create external partition!" >&2
        return 1
    }
    echo "$NAME: external partition created (ID: 1)"
    _updateProgress "$output_fd_path"

    sgdisk --new="2:${vendor_start_sector}:+${vendor_sector_size}" \
        --change-name="2:vendor" \
        --typecode="2:8300" \
        "$DEV_BLOCK_MICROSD" || {
        echo "$NAME: FATAL: failed to create vendor partition!" >&2
        return 1
    }
    echo "$NAME: vendor partition created (ID: 2)"
    _updateProgress "$output_fd_path"

    sleep 2

    if ! reReadMicroSdPartitionTable; then
        echo "$NAME: failed to re-read partition table from microSD card!" >&2
        return 1
    fi

    _updateProgress "$output_fd_path"

    echo "$NAME: repartition microSD card finished!"
    return 0
}

# Formats the external partition (p1) on microSD card as exFAT
formatExternalPartitionAsExFAT() {
    local block_path

    if ! microSdCardAvailable; then
        echo "$NAME: microSD card not found: $DEV_BLOCK_MICROSD" >&2
        return 1
    fi

    block_path="${DEV_BLOCK_MICROSD}p1"

    if [ ! -b "$block_path" ]; then
        echo "$NAME: external partition not found: $block_path" >&2
        return 1
    fi

    echo "$NAME: formatting external partition as exFAT"

    mkexfatfs -n "external" "$block_path" || {
        echo "$NAME: failed to format external partition ($block_path)!" >&2
        return 1
    }

    echo "$NAME: formatted external partition successfully!"
    return 0
}

# Formats the vendor partition (p2) on microSD card as EXT4
formatVendorPartitionAsEXT4() {
    local block_path
    local target_part_size block_count

    local BLOCK_SIZE=4096

    if ! microSdCardAvailable; then
        echo "$NAME: microSD card not found: $DEV_BLOCK_MICROSD" >&2
        return 1
    fi

    block_path="${DEV_BLOCK_MICROSD}p2"

    if [ ! -b "$block_path" ]; then
        echo "$NAME: vendor partition not found: $block_path" >&2
        return 1
    fi

    target_part_size=$(blockdev --getsize64 "$block_path") || {
        echo "$NAME: failed to get partition size from vendor ($block_path)" >&2
        return 1
    }
    block_count=$(awk -v bytes="$target_part_size" -v bs="$BLOCK_SIZE" 'BEGIN {printf "%d", bytes / bs}')

    echo "$NAME: formatting vendor partition as EXT4"

    # Force is used to supress interactive prompts. While this is not the safest approach in general,
    # the block size and target partition are determined beforehand, so this should not pose a serious risk.
    # The only requirement is that the target partition must exist and unmounted before formatting.
    mke2fs -F -t ext4 -b "$BLOCK_SIZE" "$block_path" "$block_count" || {
        echo "$NAME: failed to format vendor partition ($block_path)!" >&2
        return 1
    }

    echo "$NAME: formatted vendor partition successfully!"
    return 0
}

{
    if type "$1" >/dev/null 2>&1; then
        "$1" "$2" "$3"
        exit $?
    else
        echo "Function $1 not found" >&2
        exit 1
    fi
}
