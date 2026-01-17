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
source /tmp/scripts/property_lite.sh  # import property_lite script

GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
RESET='\033[0m'

print_message() {
    local message="$1"
    local color="$2"

    if [ -n "$color" ]; then
        echo -e "${color}${message}${RESET}"
    else
        echo "$message"
    fi
}

print_message " "
print_message "ProjectProto - eMMC cloner and repartitioner"
print_message "for selected Galaxy MSM8916 devices"
print_message "**********************************************"
print_message "Do not remove your microSD card!" $RED
print_message " "

if ! /tmp/scripts/init.sh > /dev/null; then
    print_message "init environment failed" $RED
    exit 255
fi

if ! /tmp/scripts/utilities.sh emmcAvailable; then
    print_message "eMMC device not available" $RED
    exit 255
fi

if ! /tmp/scripts/validation.sh checkRequiredTools > /dev/null; then
    print_message "Recovery does not provide required tools" $RED
    exit 255
fi

# VALIDATION
print_message "· Validation"
print_message "-- Checking for device compatibility"
if ! /tmp/scripts/validation.sh checkDevice > /dev/null; then
    print_message "!! Unsupported device. Aborting..." $YELLOW
    exit 1
fi
print_message "-- $(getProperty device_variant $PROP) detected"

print_message "-- Checking microSD card"
if ! /tmp/scripts/utilities.sh microSdCardAvailable; then
    print_message "!! No microSD card found" $YELLOW
    exit 1
fi

if ! /tmp/scripts/validation.sh compareMaxSectors > /dev/null; then
    print_message "!! Insufficient space on microSD card" $YELLOW
    exit 1
fi

if /tmp/scripts/utilities.sh projectProtoInstalled > /dev/null 2>&1; then
    print_message "ProjectProto is already installed" $GREEN
    exit 0
fi

/tmp/scripts/utilities.sh calculateMicroSdSize
print_message "-- microSD card size: $(getProperty microsd_total_size $PROP)"

print_message "-- Checking eMMC partition layout"
if ! /tmp/scripts/validation.sh checkEmmcPartitionLayout > /dev/null; then
    print_message "!! Partition layout does not meet requirements" $YELLOW
    exit 1
fi
print_message "-- Validation completed!"
print_message " "

# CLONING MEMORY
print_message "· Cloner"
print_message "-- Unmounting microSD partitions"
if ! /tmp/scripts/utilities.sh unmountMicroSdPartitions > /dev/null; then
    print_message "!! Failed to unmount microSD partitions" $YELLOW
    exit 1
fi

print_message "-- Cloning eMMC to microSD. This will take some time..."
if ! /tmp/scripts/cloner.sh cloneEmmcToMicroSd > /dev/null; then
    print_message "!! FATAL: Cloning failed." $RED
    exit 1
fi

print_message "-- eMMC cloned to microSD successfully!"
print_message " "

# REPARTITIONER
print_message "· Repartitioner"
print_message "-- Repartitioning microSD card"
if ! /tmp/scripts/repartitioner.sh repartitionMicroSdCard > /dev/null; then
    print_message "!! FATAL: Failed to repartition microSD card." $RED
    exit 1
fi

print_message "-- Formatting target partitions as EXT4 on microSD card"
for partition in system cache hidden userdata vendor; do
    print_message "   - Formatting $partition"
    if ! /tmp/scripts/repartitioner.sh formatMicroSdCardPartitionAsEXT4 "$partition" > /dev/null 2>&1; then
        print_message "!! Failed to format $partition partition on microSD card" $YELLOW
        exit 1
    fi
done

print_message "-- Re-reading partition table from microSD card"
if ! /tmp/scripts/utilities.sh reReadMicroSdPartitionTable > /dev/null; then
    print_message "!! Failed to re-read partition table." $YELLOW
    exit 1
fi

print_message "-- microSD card repartitioned successfully!"
print_message " "

# MISC
print_message "· Miscellaneous"
print_message "-- Calculating target partition sizes on microSD card"
if /tmp/scripts/utilities.sh calculateMicroSdPartitionSizes > /dev/null; then
    print_message "   - System: $(getProperty microsd_system_size $PROP)"
    print_message "   - Cache: $(getProperty microsd_cache_size $PROP)"
    print_message "   - Hidden: $(getProperty microsd_hidden_size $PROP)"
    print_message "   - Userdata: $(getProperty microsd_userdata_size $PROP)"
    print_message "   - Vendor: $(getProperty microsd_vendor_size $PROP)"
fi

print_message "-- Mounting target partitions"
for partition in system cache hidden userdata vendor; do
    if [ "$partition" = "userdata" ]; then
        mount_point="/data_extsd"
    else
        mount_point="/${partition}_extsd"
    fi

    if ! /tmp/scripts/utilities.sh mountMicroSdCardPartition "$partition" > /dev/null; then
        print_message "!! Failed to mount $partition partition from microSD card" $YELLOW
    else
        print_message "-- Mounted $partition partition as $mount_point"
    fi
done
print_message " "

if /tmp/scripts/utilities.sh projectProtoInstalled > /dev/null 2>&1; then
    print_message "ProjectProto installed successfully!" $GREEN
else
    print_message "ProjectProto not properly installed!" $YELLOW
fi
