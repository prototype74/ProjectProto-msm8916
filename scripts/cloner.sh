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

readonly NAME="cloner"

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
    local output_fd_path="$1"
    local installer_type="${2:-adb}"
    local progress_start="$3"
    local progress_range="$4"
    local dd_status_path="/tmp/dd_status"
    local emmc_size
    local dd_pid dd_exit

    if ! emmcAvailable; then
        echo "$NAME: eMMC device not found: $DEV_BLOCK_EMMC" >&2
        return 1
    fi

    if ! microSdCardAvailable; then
        echo "$NAME: microSD card not found: $DEV_BLOCK_MICROSD" >&2
        return 1
    fi

    emmc_size=$(blockdev --getsize64 "$DEV_BLOCK_EMMC") || {
        echo "$NAME: failed to get eMMC size" >&2
        return 1
    }

    echo "$NAME: cloning eMMC to microSD card started! (size: ${emmc_size} bytes)"

    dd if="$DEV_BLOCK_EMMC" of="$DEV_BLOCK_MICROSD" bs=4m 2>"$dd_status_path" &
    dd_pid=$!

    sleep 1 # wait for dd to start writing before entering progress loop

    # Cloning can take a long time depending on the eMMC size and write speed.
    # To avoid the process from appearing stuck, send USR1 to dd periodically
    # to get the current write position and update the progress (bar) accordingly.
    if [ -p "$output_fd_path" ] || [ -c "$output_fd_path" ]; then
        local bytes_written progress

        while kill -0 "$dd_pid" 2>/dev/null; do
            kill -USR1 "$dd_pid" 2>/dev/null
            sleep 1 # wait for dd output
            bytes_written=$(awk '/bytes/ {print $1}' "$dd_status_path" 2>/dev/null | tail -1)

            if [ -n "$bytes_written" ] && [ "$bytes_written" != "0" ]; then
                # Update the progress bar in TWRP's GUI
                if [ "$installer_type" = "flashable" ]; then
                    progress=$(awk -v written="$bytes_written" \
                                -v total="$emmc_size" \
                                -v start="$progress_start" \
                                -v range="$progress_range" \
                            'BEGIN { p = start + (written / total) * range; printf "%.2f", p }')
                    echo "set_progress $progress" > "$output_fd_path"
                # Show text based progress in ADB terminal
                elif [ "$installer_type" = "adb" ]; then
                    progress=$(awk -v written="$bytes_written" \
                                -v total="$emmc_size" \
                            'BEGIN { printf "%.1f", (written / total) * 100 }')
                    printf "\r   >>> Cloning... %s%%" "$progress" > "$output_fd_path"
                fi
            fi
        done

        if [ "$installer_type" = "adb" ]; then
            printf "\r%-30s\r" " " > "$output_fd_path"
        fi
    fi

    wait "$dd_pid"
    dd_exit=$?

    rm -f "$dd_status_path" || {
        echo "$NAME: unable to remove dd_status file!" >&2
    }

    if [ "$dd_exit" -ne 0 ]; then
        echo "$NAME: cloning process failed!" >&2
        return 1
    fi

    blockdev --flushbufs "$DEV_BLOCK_MICROSD" || {
        echo "$NAME: failed to flush write buffers to microSD card!" >&2
        return 1
    }

    sleep 2 # ensure caches are cleaned up and kernel ready to read new table

    if ! reReadMicroSdPartitionTable; then
        echo "$NAME: failed to re-read partition table from microSD card! Partitions still mounted?" >&2
        return 1
    fi

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
        "$1" "$2" "$3" "$4" "$5"
        exit $?
    else
        echo "Function $1 not found" >&2
        exit 1
    fi
}
