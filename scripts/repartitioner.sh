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

readonly NAME="repartitioner"

# Repartition microSD card after cloning:
# - enlarge system partition
# - keep original sizes for cache and hidden
# - assign remaining space to userdata
# - delete and recreate system/cache/hidden/userdata partitions
# - add vendor partition at the end of the device
repartitionMicroSdCard() {
    local microsd_partition_table partition_names
    local system_id cache_id hidden_id userdata_id vendor_id
    local vendor_start_sector
    local cache_sector_size hidden_sector_size vendor_sector_size
    local total_sectors sector_size
    local part_id part_name

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
    cache_id=$(echo "$partition_names" | grep ":cache$" | cut -d: -f1)
    hidden_id=$(echo "$partition_names" | grep ":hidden$" | cut -d: -f1)
    userdata_id=$(echo "$partition_names" | grep ":userdata$" | cut -d: -f1)

    checkNumeric "$NAME" "system_id" "$system_id" || return 1
    checkNumeric "$NAME" "cache_id" "$cache_id" || return 1
    checkNumeric "$NAME" "hidden_id" "$hidden_id" || return 1
    checkNumeric "$NAME" "userdata_id" "$userdata_id" || return 1

    if [ "$cache_id" -ne $((system_id + 1)) ] ||
       [ "$hidden_id" -ne $((cache_id + 1)) ] ||
       [ "$userdata_id" -ne $((hidden_id + 1)) ]; then
        echo "$NAME: partition IDs are not consecutive!" >&2
        return 1
    fi

    cache_sector_size=$(blockdev --getsz "${DEV_BLOCK_MICROSD}p${cache_id}") || {
        printf "$NAME: failed to get sector size from cache (%sp%s)\n" "$DEV_BLOCK_MICROSD" "$cache_id" >&2
        return 1
    }

    hidden_sector_size=$(blockdev --getsz "${DEV_BLOCK_MICROSD}p${hidden_id}") || {
        printf "$NAME: failed to get sector size from hidden (%sp%s)\n" "$DEV_BLOCK_MICROSD" "$hidden_id" >&2
        return 1
    }

    total_sectors=$(blockdev --getsz "$DEV_BLOCK_MICROSD") || {
        echo "$NAME: failed to get total sector size from microSD!" >&2
        return 1
    }
    total_sectors=$((total_sectors - 41)) # last 41 sectors are not useable

    if [ $((total_sectors % 2)) -eq 0  ]; then
        # This should never happen
        echo "$NAME: WARN: Adjusting total sectors to an odd number!"
        total_sectors=$((total_sectors - 1))
    fi

    # sector size is usually 512 bytes
    sector_size=$(blockdev --getss "$DEV_BLOCK_MICROSD") || {
        echo "$NAME: failed to get sector size from microSD!" >&2
        return 1
    }

    vendor_sector_size=$((1024 * 1024 * 700 / sector_size))
    vendor_start_sector=$((total_sectors - vendor_sector_size + 1))
    vendor_id=$((userdata_id + 1))

    echo "$NAME: repartitioning microSD card started!"

    # Keep IDs in descending order!
    for part_id in "$userdata_id" "$hidden_id" "$cache_id" "$system_id"; do
        part_name=$(echo "$partition_names" | awk -F: -v part_id="$part_id" '$1 == part_id {print $2}')
        sgdisk --delete="$part_id" "$DEV_BLOCK_MICROSD" || {
            echo "$NAME: failed to delete $part_name partition (ID: $part_id)!" >&2
            return 1
        }
        echo "$NAME: deleted $part_name partition (ID: $part_id)"
    done

    echo "$NAME: creating new partitions"

    sgdisk --new="${system_id}::+3584M" \
        --change-name="${system_id}:system" \
        --typecode="${system_id}:8300" \
        "$DEV_BLOCK_MICROSD" || {
        echo "$NAME: FATAL: failed to create new system partition!" >&2
        return 1
    }
    echo "$NAME: system partition created (ID: $system_id)"

    sgdisk --new="${cache_id}::+${cache_sector_size}S" \
        --change-name="${cache_id}:cache" \
        --typecode="${cache_id}:8300" \
        "$DEV_BLOCK_MICROSD" || {
        echo "$NAME: FATAL: failed to create new cache partition!" >&2
        return 1
    }
    echo "$NAME: cache partition created (ID: $cache_id)"

    sgdisk --new="${hidden_id}::+${hidden_sector_size}S" \
        --change-name="${hidden_id}:hidden" \
        --typecode="${hidden_id}:8300" \
        "$DEV_BLOCK_MICROSD" || {
        echo "$NAME: FATAL: failed to create new hidden partition!" >&2
        return 1
    }
    echo "$NAME: hidden partition created (ID: $hidden_id)"

    sgdisk --new="${userdata_id}::$((vendor_start_sector - 1))" \
        --change-name="${userdata_id}:userdata" \
        --typecode="${userdata_id}:8300" \
        "$DEV_BLOCK_MICROSD" || {
        echo "$NAME: FATAL: failed to create new userdata partition!" >&2
        return 1
    }
    echo "$NAME: userdata partition created (ID: $userdata_id)"

    sgdisk --new="${vendor_id}:${vendor_start_sector}:${total_sectors}" \
        --change-name="${vendor_id}:vendor" \
        --typecode="${vendor_id}:8300" \
        "$DEV_BLOCK_MICROSD" || {
        echo "$NAME: FATAL: failed to create new vendor partition!" >&2
        return 1
    }
    echo "$NAME: vendor partition created (ID: $vendor_id)"

    sleep 2

    if ! reReadMicroSdPartitionTable; then
        echo "$NAME: failed to re-read partition table from microSD card!" >&2
        return 1
    fi

    echo "$NAME: repartition microSD card finished!"
    return 0
}

# Formats a specified partition on microSD card as an EXT4 filesystem.
# Supported partitions are system, cache, hidden, userdata and vendor.
formatMicroSdCardPartitionAsEXT4() {
    local part_name="$1"
    local microsd_partition_table partition_names
    local target_part_id target_part_size
    local block_count block_path

    local PARTITIONS="system cache hidden userdata vendor"
    local BLOCK_SIZE=4096
    local USERDATA_OFFSET=5 # reserved for 64-bit crypto footer (encryption)

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
    target_part_size=$(blockdev --getsize64 "$block_path") || {
        printf "$NAME: failed to get partition size from %s (%s)\n" "$part_name" "$block_path" >&2
        return 1
    }
    block_count=$(awk -v bytes="$target_part_size" -v bs="$BLOCK_SIZE" 'BEGIN {printf "%d", bytes / bs}')

    if [ "$part_name" = "userdata" ]; then
        block_count=$(( block_count - USERDATA_OFFSET ))
    fi

    echo "$NAME: formatting $part_name partition"

    # Force is used to supress interactive prompts. While this is not the safest approach in general,
    # the block size and target partition are determined beforehand, so this should not pose a serious risk.
    # The only requirement is that the target partition must exist and unmounted before formatting.
    mke2fs -F -t ext4 -b "$BLOCK_SIZE" "$block_path" "$block_count" || {
        echo "$NAME: failed to format $part_name ($block_path)!" >&2
        return 1
    }

    echo "$NAME: formatted $part_name successfully!"
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
