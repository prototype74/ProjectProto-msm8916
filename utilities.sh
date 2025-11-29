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

NAME="utilities"

# Check if eMMC is available
emmcAvailable() {
    [ -b "$DEV_BLOCK_EMMC" ] && return 0 || return 1;
}

# Check if microSD card is available
microSdCardAvailable() {
    [ -b "$DEV_BLOCK_MICROSD" ] && return 0 || return 1;
}

# Calculate size of microSD card in gibibyte
calculateMicroSdSize() {
    local microsd_max_sectors
    local sectors
	local result

    if ! microSdCardAvailable; then
        echo "$NAME: microSD card not found: $DEV_BLOCK_MICROSD" >&2
        return 1
    fi

    microsd_max_sectors=$(blockdev --getsz "$DEV_BLOCK_MICROSD")
    sectors=$(blockdev --getss "$DEV_BLOCK_MICROSD")
    result=$(awk -v sectors="$sectors" -v max_sectors="$microsd_max_sectors" \
        'BEGIN {printf "%.1f", (max_sectors * sectors) / (1024^3)}')

    updateProperty "microsd_size" "$result" "$PROP"
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

{
    if type "$1" >/dev/null 2>&1; then
        "$1"
        exit $?
    else
        echo "Function $1 not found" >&2
        exit 1
    fi
}
