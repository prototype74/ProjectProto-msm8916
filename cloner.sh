#!/sbin/sh
#
# Copyright (c) 2025 prototype74
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

source /tmp/scripts/constants.sh  # import constants script
source /tmp/scripts/property_lite.sh  # import property_lite script
source /tmp/scripts/utilities.sh  # import utilities script

NAME="cloner"

# Ensure the target partitions between eMMC and microSD card are
# identical after clone
_checkMicroSdPartitionLayout() {
    local microsd_partition_table
    local partition_names part_name
    local microsd_partition_count emmc_partition_count
    local microsd_part_id emmc_part_id
    local microsd_system_start_sector emmc_system_start_sector

    if ! microSdCardAvailable; then
        echo "$NAME: microSD card not found: $DEV_BLOCK_MICROSD" >&2
        return 1
    fi

    microsd_partition_table=$(sgdisk --print "$DEV_BLOCK_MICROSD" 2>/dev/null) || {
        echo "$NAME: failed to read microSD card partition table" >&2
        return 1
    }

    partition_names=$(printf '%s\n' "$microsd_partition_table" | awk '/^[[:space:]]*[0-9]+/ {print $1":"$2":"$7}')
    microsd_partition_count=$(printf '%s\n' "$partition_names" | wc -l)
    emmc_partition_count=$(getProperty "emmc_partition_count" "$PROP")

    checkNumeric "$NAME" "microsd_partition_count" "$microsd_partition_count" || return 1
    checkNumeric "$NAME" "emmc_partition_count" "$emmc_partition_count" || return 1

    if [ "$microsd_partition_count" -ne "$emmc_partition_count" ]; then
        echo "$NAME: number of partitions on microSD card does not match the eMMC!" >&2
        return 1
    fi

    echo "$NAME: comparing target partition IDs between eMMC and microSD card"

    for part_name in system cache hidden userdata; do
        microsd_part_id=$(echo "$partition_names" | grep ":$part_name$" | cut -d: -f1)
        emmc_part_id=$(getProperty "${part_name}_partition_id" "$PROP")

        checkNumeric "$NAME" "microsd_${part_name}_id" "$microsd_part_id" || return 1
        checkNumeric "$NAME" "emmc_${part_name}_id" "$emmc_part_id" || return 1

        if [ "$microsd_part_id" -ne "$emmc_part_id" ]; then
            echo "$NAME: $part_name partition ID mismatch between eMMC and microSD card!" >&2
            return 1
        fi
    done

    microsd_system_start_sector=$(echo "$partition_names" | grep ":system$" | cut -d: -f2)
    emmc_system_start_sector=$(getProperty "system_start_sector" "$PROP")

    checkNumeric "$NAME" "microsd_system_start_sector" "$microsd_system_start_sector" || return 1
    checkNumeric "$NAME" "emmc_system_start_sector" "$emmc_system_start_sector" || return 1

    if [ "$microsd_system_start_sector" -ne "$emmc_system_start_sector" ]; then
        echo "$NAME: system start sectors from eMMC and microSD card do not match!" >&2
        return 1
    fi

    return 0
}

# Clone the entire eMMC storage to microSD card
cloneEmmcToMicroSd() {
    if ! emmcAvailable; then
        echo "$NAME: eMMC device not found: $DEV_BLOCK_EMMC" >&2
        return 1
    fi

    if ! microSdCardAvailable; then
        echo "$NAME: microSD card not found: $DEV_BLOCK_MICROSD" >&2
        return 1
    fi

    echo "$NAME: cloning eMMC to microSD card started!"

    dd if="$DEV_BLOCK_EMMC" of="$DEV_BLOCK_MICROSD" bs=4M conv=fsync || {
        echo "$NAME: cloning process failed!" >&2
        return 1
    }

    sleep 2 # ensure caches are cleaned up and kernel ready to read new table

    echo "$NAME: checking the partition layout on microSD card after cloning"

    if _checkMicroSdPartitionLayout; then
        echo "$NAME: cloned eMMC to microSD card successfully!"
        return 0
    fi

    echo "$NAME: failed to clone eMMC to microSD card!" >&2
    return 1
}

{
    if type "$1" >/dev/null 2>&1; then
        "$1"
        exit $?
    else
        echo "Function $1 not found" >&2
        exit 1
    fi
}
