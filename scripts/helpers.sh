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

source /tmp/scripts/constants.sh  # import constants script

NAME="helpers"

# Check if eMMC is available
emmcAvailable() {
    [ -b "$DEV_BLOCK_EMMC" ] && return 0 || return 1;
}

# Check if microSD card is available
microSdCardAvailable() {
    [ -b "$DEV_BLOCK_MICROSD" ] && return 0 || return 1;
}

# Check if given value is a valid number
checkNumeric() {
    local scr_name="$1"
    local name="$2"
    local value="$3"

    if [ -z "$value" ]; then
        echo "$scr_name: '$name' is empty!" >&2
        return 1
    fi

    case "$value" in
        *[!0-9]*)
            echo "$scr_name: '$name' is not numeric: '$value'" >&2
            return 1
            ;;
    esac

    return 0
}

# Unmount all partitions on microSD card if any are mounted
unmountMicroSdPartitions() {
    local mountpoints mp

    mountpoints=$(grep "^$DEV_BLOCK_MICROSD" /proc/mounts | awk '{print $2}')

    if [ -z "$mountpoints" ]; then
        return 0
    fi

    echo "$NAME: unmounting partitions from microSD card"

    for mp in $mountpoints; do
        if ! umount "$mp"; then
            echo "$NAME: failed to unmount $mp" >&2
            return 1
        fi
    done

    echo "$NAME: unmounted all partitions from microSD card"
    return 0
}

# Re-read the microSD card partition table. This is required if partitions on
# microSD card were modified (e.g. by sgdisk).
reReadMicroSdPartitionTable() {
    if ! blockdev --rereadpt "$DEV_BLOCK_MICROSD" 2>/dev/null; then
        unmountMicroSdPartitions
        # Another attempt to re-read the partition table
        if ! blockdev --rereadpt "$DEV_BLOCK_MICROSD"; then
            return 1
        fi
    fi

    return 0
}
