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

NAME="validation"

# Check for supported device
checkDevice() {
    local device="unknown"
    local bootloader

    echo "$NAME: start device check"

    bootloader=$(getprop ro.boot.bootloader)

    case "$bootloader" in
        "J510F"*|"J510GN"*|"J510K"*|"J510L"*|"J510MN"*|"J510S"*|"J510UN"*)
            # Galaxy J5 2016 LTE
            device="j5xnlte"
            ;;
        "J510H"*)
            # Galaxy J5 2016 3G
            device="j5x3g"
            ;;
        *)
            echo "$NAME: unsupported device: $bootloader"
            return 1
            ;;
    esac

    echo "$NAME: device supported ($device)"
    updateProperty "device_variant" "$device" "$PROP"
    return 0
}

# Compare sector sizes between eMMC and microSD card
compareMaxSectors() {
    local emmc_max_sectors
    local microsd_max_sectors

    # Ensure both block devices exist
    if ! emmcAvailable; then
        echo "$NAME: eMMC device not found: $DEV_BLOCK_EMMC" >&2
        return 1
    fi

    if ! microSdCardAvailable; then
        echo "$NAME: microSD card not found: $DEV_BLOCK_MICROSD" >&2
        return 1
    fi

    microsd_max_sectors=$(blockdev --getsz "$DEV_BLOCK_MICROSD" 2>/dev/null) || {
        echo "$NAME: failed to retrieve sector size of microSD card" >&2
        return 1
    }

    checkNumeric "$NAME" "microsd_max_sectors" "$microsd_max_sectors" || return 1

    # ~ 14.3 GiB
    if [ "$microsd_max_sectors" -lt 30000000 ]; then
        echo "$NAME: microSD card size is lower than 16 GB" >&2
        return 1
    fi

    emmc_max_sectors=$(blockdev --getsz "$DEV_BLOCK_EMMC" 2>/dev/null) || {
        echo "$NAME: failed to retrieve sector size of eMMC" >&2
        return 1
    }

    checkNumeric "$NAME" "emmc_max_sectors" "$emmc_max_sectors" || return 1

    if [ "$microsd_max_sectors" -ge "$emmc_max_sectors" ]; then
        echo "$NAME: sufficient max sectors on microSD card"
        return 0
    fi

    echo "$NAME: not enough sectors on microSD card" >&2
    return 1
}

# Ensure target partitions are in correct order
# system -> cache -> hidden -> userdata
# Stores required partition IDs and sizes before cloning
checkEmmcPartitionLayout() {
    local emmc_partition_table
    local partition_names
    local system_id cache_id hidden_id userdata_id last_id
    local system_start_sector
    local partition_count

    if ! emmcAvailable; then
        echo "$NAME: eMMC device not found: $DEV_BLOCK_EMMC" >&2
        return 1
    fi

    emmc_partition_table=$(sgdisk --print "$DEV_BLOCK_EMMC" 2>/dev/null) || {
        echo "$NAME: failed to read eMMC partition table" >&2
        return 1
    }

    # Extract id, start sector and name e.g. 25:393216:system
    partition_names=$(printf '%s\n' "$emmc_partition_table" | awk '/^[[:space:]]*[0-9]+/ {print $1":"$2":"$7}')

    system_id=$(echo "$partition_names" | grep ":system$" | cut -d: -f1)
    cache_id=$(echo "$partition_names" | grep ":cache$" | cut -d: -f1)
    hidden_id=$(echo "$partition_names" | grep ":hidden$" | cut -d: -f1)
    userdata_id=$(echo "$partition_names" | grep ":userdata$" | cut -d: -f1)

    checkNumeric "$NAME" "system_id" "$system_id" || return 1
    checkNumeric "$NAME" "cache_id" "$cache_id" || return 1
    checkNumeric "$NAME" "hidden_id" "$hidden_id" || return 1
    checkNumeric "$NAME" "userdata_id" "$userdata_id" || return 1

    # check partition order
    if [ "$cache_id" -ne $((system_id + 1)) ] ||
       [ "$hidden_id" -ne $((cache_id + 1)) ] ||
       [ "$userdata_id" -ne $((hidden_id + 1)) ]; then
        echo "$NAME: partition IDs are not consecutive!" >&2
        return 1
    fi

    last_id=$(echo "$partition_names" | tail -n1 | cut -d: -f1)
    checkNumeric "$NAME" "last_id" "$last_id" || return 1

    if [ "$userdata_id" -lt "$last_id" ]; then
        echo "$NAME: additional partition(s) found after userdata!"
        return 1
    fi

    partition_count=$(printf '%s\n' "$emmc_partition_table" | grep -E '^[[:space:]]*[0-9]+' | wc -l)
    system_start_sector=$(echo "$partition_names" | grep ":system$" | cut -d: -f2)

    checkNumeric "$NAME" "partition_count" "$partition_count" || return 1
    checkNumeric "$NAME" "system_start_sector" "$system_start_sector" || return 1

    updateProperty "emmc_partition_count" "$partition_count" "$PROP"
    updateProperty "system_start_sector" "$system_start_sector" "$PROP"
    updateProperty "system_partition_id" "$system_id" "$PROP"
    updateProperty "cache_partition_id" "$cache_id" "$PROP"
    updateProperty "hidden_partition_id" "$hidden_id" "$PROP"
    updateProperty "userdata_partition_id" "$userdata_id" "$PROP"
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
