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
source /tmp/scripts/utilities.sh  # import utilities script

NAME="cloner"

# Ensure the partition layouts between eMMC and microSD card are
# identical after clone
_checkMicroSdPartitionLayout() {
    local emmc_partition_table microsd_partition_table
    local emmc_partition_names microsd_partition_names

    if ! emmcAvailable; then
        echo "$NAME: eMMC device not found: $DEV_BLOCK_EMMC" >&2
        return 1
    fi

    if ! microSdCardAvailable; then
        echo "$NAME: microSD card not found: $DEV_BLOCK_MICROSD" >&2
        return 1
    fi

    emmc_partition_table=$(sgdisk --print "$DEV_BLOCK_EMMC" 2>/dev/null) || {
        echo "$NAME: failed to read eMMC partition table" >&2
        return 1
    }

    microsd_partition_table=$(sgdisk --print "$DEV_BLOCK_MICROSD" 2>/dev/null) || {
        echo "$NAME: failed to read microSD card partition table" >&2
        return 1
    }

    emmc_partition_names=$(printf '%s\n' "$emmc_partition_table" | awk '/^[[:space:]]*[0-9]+/ {print $1":"$2":"$7}')
    microsd_partition_names=$(printf '%s\n' "$microsd_partition_table" | awk '/^[[:space:]]*[0-9]+/ {print $1":"$2":"$7}')

    if [ "$microsd_partition_names" != "$emmc_partition_names" ]; then
        echo "$NAME: the partition layout of microSD card does not match that of eMMC!" >&2
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
