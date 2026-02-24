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

readonly TMP_SCRIPTS="/tmp/scripts"
readonly PARTITIONS="system cache hidden userdata vendor"
readonly GREEN='\033[1;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[1;31m'
readonly RESET='\033[0m'

set -e

print_message() {
    local message="$1"
    local color="$2"

    if [ -n "$color" ]; then
        echo -e "${color}${message}${RESET}"
    else
        echo "$message"
    fi
}

abort() {
    local message="$1"
    local exit_code="${2:-1}"

    print_message "$message" "$RED"
    print_message " "
    sleep 0.5
    exit "$exit_code"
}

run() {
    local module="$1"
    local script

    if [ -z "$module" ]; then
        echo "run: no module specified" >&2
        return 2
    fi

    shift

    script="$TMP_SCRIPTS/${module}.sh"

    if [ ! -f "$script" ]; then
        echo "run: module '$module' not found" >&2
        return 127
    fi

    "$script" "$@"
}

source $TMP_SCRIPTS/constants.sh  # import constants script
source $TMP_SCRIPTS/property_lite.sh  # import property_lite script

print_message " "
print_message "ProjectProto - eMMC cloner and repartitioner"
print_message "for selected Galaxy MSM8916 devices"
print_message "**********************************************"
print_message "Do not remove your microSD card!" $RED
print_message " "

run init > /dev/null || abort "Failed to initialize environment" 255
run utilities emmcAvailable || abort "eMMC device not available" 255
run validation checkRequiredTools > /dev/null || abort "Recovery does not provide required tools" 127

# VALIDATION
print_message "· Validation"
print_message "-- Checking for device compatibility"
run validation checkDevice > /dev/null || abort "!! Unsupported device. Aborting..."
print_message "-- $(getProperty device_variant $PROP) detected"

print_message "-- Checking microSD card"
run utilities microSdCardAvailable || abort "!! No microSD card detected"
run validation compareMaxSectors > /dev/null || abort "!! Insufficient space on microSD card"

if run utilities projectProtoInstalled > /dev/null 2>&1; then
    print_message " "
    print_message "ProjectProto is already installed" $GREEN
    print_message " "
    exit 0
fi

run utilities calculateMicroSdSize
print_message "-- microSD card size: $(getProperty microsd_total_size $PROP)"

print_message "-- Checking eMMC partition layout"
run validation checkEmmcPartitionLayout > /dev/null || abort "!! Partition layout does not meet requirements"

print_message "-- Validation completed!"
print_message " "

# CLONING MEMORY
print_message "· Cloner"
print_message "-- Unmounting microSD partitions"
run utilities unmountMicroSdPartitions > /dev/null || abort "!! Failed to unmount microSD partitions"

print_message "-- Cloning eMMC to microSD. This may take a while..."
run cloner cloneEmmcToMicroSd > /dev/null || abort "!! FATAL: Cloning process failed"
print_message "-- eMMC cloned to microSD successfully!"
print_message " "

# REPARTITIONER
print_message "· Repartitioner"
print_message "-- Repartitioning microSD card"
run repartitioner repartitionMicroSdCard > /dev/null || abort "!! FATAL: Failed to repartition microSD card"

print_message "-- Formatting target partitions as EXT4 on microSD card"
for partition in $PARTITIONS; do
    print_message "   - Formatting $partition"
    run repartitioner formatMicroSdCardPartitionAsEXT4 "$partition" > /dev/null 2>&1 || \
        abort "!! Failed to format $partition partition on microSD card"
done

print_message "-- Re-reading partition table from microSD card"
run utilities reReadMicroSdPartitionTable > /dev/null || abort "!! Failed to re-read partition table"
print_message "-- microSD card repartitioned successfully!"
print_message " "

# MISC
print_message "· Miscellaneous"
print_message "-- Calculating target partition sizes on microSD card"
if run utilities calculateMicroSdPartitionSizes > /dev/null; then
    print_message "   - System: $(getProperty microsd_system_size $PROP)"
    print_message "   - Cache: $(getProperty microsd_cache_size $PROP)"
    print_message "   - Hidden: $(getProperty microsd_hidden_size $PROP)"
    print_message "   - Userdata: $(getProperty microsd_userdata_size $PROP)"
    print_message "   - Vendor: $(getProperty microsd_vendor_size $PROP)"
fi

print_message "-- Mounting target partitions"
for partition in $PARTITIONS; do
    if [ "$partition" = "userdata" ]; then
        mount_point="/data_sdc2"
    else
        mount_point="/${partition}_sdc2"
    fi

    if ! run utilities mountMicroSdCardPartition "$partition" > /dev/null; then
        print_message "   ! Failed to mount $partition partition from microSD card" $YELLOW
    else
        print_message "   - Mounted $partition partition as $mount_point"
    fi
done
print_message " "

if run utilities projectProtoInstalled > /dev/null 2>&1; then
    print_message "ProjectProto installed successfully!" $GREEN
else
    print_message "ProjectProto not properly installed!" $YELLOW
fi
print_message " "
