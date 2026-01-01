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
source /tmp/scripts/property_lite.sh  # import property_lite script

readonly NAME="utilities"

# Calculate size of microSD card in gibibyte
calculateMicroSdSize() {
    local microsd_max_sectors
    local sector_size
    local result

    if ! microSdCardAvailable; then
        echo "$NAME: microSD card not found: $DEV_BLOCK_MICROSD" >&2
        return 1
    fi

    microsd_max_sectors=$(blockdev --getsz "$DEV_BLOCK_MICROSD")
    sector_size=$(blockdev --getss "$DEV_BLOCK_MICROSD")
    result=$(awk -v sector_size="$sector_size" -v max_sectors="$microsd_max_sectors" \
        'BEGIN {printf "%.1f", (max_sectors * sector_size) / (1024^3)}')

    updateProperty "microsd_total_size" "${result} GiB" "$PROP"
    return 0
}

# Calculate target partition sizes from microSD card
calculateMicroSdPartitionSizes() {
    local microsd_partition_table
    local partition_names
    local sector_size
    local part_bytes part_id part_name part_sectors part_size

    if ! microSdCardAvailable; then
        echo "$NAME: microSD card not found: $DEV_BLOCK_MICROSD" >&2
        return 1
    fi

    microsd_partition_table=$(sgdisk --print "$DEV_BLOCK_MICROSD" 2>/dev/null) || {
        echo "$NAME: failed to read microSD card partition table" >&2
        return 1
    }

    partition_names=$(printf '%s\n' "$microsd_partition_table" | awk '/^[[:space:]]*[0-9]+/ {print $1":"$7}')
    sector_size=$(blockdev --getss "$DEV_BLOCK_MICROSD")

    for part_name in system cache hidden userdata vendor; do
        part_id=$(echo "$partition_names" | grep ":$part_name$" | cut -d: -f1)
        checkNumeric "$NAME" "${part_name}_id" "$part_id" || {
            updateProperty "microsd_${part_name}_size" "0 Bytes" "$PROP"
            continue
        }
        part_sectors=$(blockdev --getsz "${DEV_BLOCK_MICROSD}p${part_id}")
        part_size=$(awk -v part_sectors="$part_sectors" -v sector_size="$sector_size" \
            'BEGIN {
                bytes = (part_sectors * sector_size)
                if (bytes < 1024)        printf "%.1f %s", bytes, "Bytes";
                else if (bytes < 1024^2) printf "%.1f %s", bytes / 1024, "KiB";
                else if (bytes < 1024^3) printf "%.1f %s", bytes / (1024^2), "MiB";
                else if (bytes < 1024^4) printf "%.1f %s", bytes / (1024^3), "GiB";
                else                     printf "%.1f %s", bytes / (1024^4), "TiB";
            }')
        updateProperty "microsd_${part_name}_size" "$part_size" "$PROP"
    done

    return 0
}

# Set partition count available on microSD card
setPartitionCount() {
    local count

    if ! microSdCardAvailable; then
        echo "$NAME: microSD card not found: $DEV_BLOCK_MICROSD" >&2
        return 1
    fi

    count=$(sgdisk --print "$DEV_BLOCK_MICROSD" | grep -E '^[[:space:]]*[0-9]+' | wc -l)
    updateProperty "microsd_partition_count" "$count" "$PROP"
    return 0
}

# Check if ProjectProto is installed on microSD card
projectProtoInstalled() {
    local microsd_partition_table
    local partition_names
    local system_id vendor_id
    local system_bytes vendor_bytes

    # Expected sizes in bytes
    local EXPECT_SYSTEM_SIZE=$((1024 * 1024 * 3584))  # 3.5 GiB
    local EXPECT_VENDOR_SIZE=$((1024 * 1024 * 700))   # 700 MiB

    if ! microSdCardAvailable; then
        echo "$NAME: microSD card not found: $DEV_BLOCK_MICROSD" >&2
        return 1
    fi

    microsd_partition_table=$(sgdisk --print "$DEV_BLOCK_MICROSD" 2>/dev/null) || {
        echo "$NAME: failed to read microSD card partition table" >&2
        return 1
    }

    partition_names=$(printf '%s\n' "$microsd_partition_table" | awk '/^[[:space:]]*[0-9]+/ {print $1":"$7}')
    system_id=$(echo "$partition_names" | grep ":system$" | cut -d: -f1)
    vendor_id=$(echo "$partition_names" | grep ":vendor$" | cut -d: -f1)

    checkNumeric "$NAME" "system_id" "$system_id" || {
        echo "$NAME: ProjectProto not installed (system)" >&2
        return 1
    }

    checkNumeric "$NAME" "vendor_id" "$vendor_id" || {
        echo "$NAME: ProjectProto not installed (vendor)" >&2
        return 1
    }

    system_bytes=$(blockdev --getsize64 "${DEV_BLOCK_MICROSD}p${system_id}")
    vendor_bytes=$(blockdev --getsize64 "${DEV_BLOCK_MICROSD}p${vendor_id}")

    if [ "$system_bytes" -ne "$EXPECT_SYSTEM_SIZE" ] || [ "$vendor_bytes" -ne "$EXPECT_VENDOR_SIZE" ]; then
        echo "$NAME: ProjectProto not installed (size mismatch)" >&2
        return 1
    fi

    echo "$NAME: ProjectProto is installed"
    return 0
}

# Check whether any partition on microSD card is currently mounted
isMicroSdMounted() {
    grep -q "^$DEV_BLOCK_MICROSD" /proc/mounts
}

# Mount a specified partition on microSD card.
# Supported partitions are system, cache, hidden, userdata and vendor.
# The partition is mounted to /<part_name>_extsd (userdata to /data_extsd).
mountMicroSdCardPartition() {
    local part_name="$1"
    local microsd_partition_table partition_names
    local target_part_id
    local block_path
    local mount_dir_name

    local PARTITIONS="system cache hidden userdata vendor"

    if ! microSdCardAvailable; then
        echo "$NAME: microSD card not found: $DEV_BLOCK_MICROSD" >&2
        return 1
    fi

    if ! printf '%s\n' $PARTITIONS | grep -qxF "$part_name"; then
        echo "$NAME: invalid partition name: $part_name" >&2
        return 1
    fi

    microsd_partition_table=$(sgdisk --print "$DEV_BLOCK_MICROSD" 2>/dev/null) || {
        echo "$NAME: failed to read microSD card partition table" >&2
        return 1
    }

    partition_names=$(printf '%s\n' "$microsd_partition_table" | awk '/^[[:space:]]*[0-9]+/ {print $1":"$7}')
    target_part_id=$(echo "$partition_names" | grep ":${part_name}$" | cut -d: -f1)

    checkNumeric "$NAME" "${part_name}_id" "$target_part_id" || return 1

    block_path="${DEV_BLOCK_MICROSD}p${target_part_id}"

    if [ "$part_name" = "userdata" ]; then
        mount_dir_name="/data_extsd"
    else
        mount_dir_name="/${part_name}_extsd"
    fi

    if grep -q "^$block_path $mount_dir_name[[:space:]]" /proc/mounts; then
        echo "$NAME: $block_path already mounted on $mount_dir_name"
        return 0
    fi

    if ! [ -d "$mount_dir_name" ]; then
        mkdir -p "$mount_dir_name" || {
            echo "$NAME: failed to create directory '$mount_dir_name'" >&2
            return 1;
        }
    fi

    mount "$block_path" "$mount_dir_name" || {
        echo "$NAME: failed to mount $block_path as $mount_dir_name" >&2
        return 1
    }

    echo "$NAME: $block_path mounted as $mount_dir_name"
    return 0
}

{
    if type "$1" >/dev/null 2>&1; then
        "$1" "$2"
        exit $?
    else
        echo "Function $1 not found" >&2
        exit 1
    fi
}
