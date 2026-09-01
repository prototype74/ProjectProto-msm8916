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
readonly LOG_FILE="/tmp/ProjectProtoLite.log"
readonly GREEN='\033[1;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[1;31m'
readonly RESET='\033[0m'

set -e

if [ -e "$LOG_FILE" ]; then
    rm -f "$LOG_FILE"
fi

exec 4>&1 # Console file descriptor
exec 3>>"$LOG_FILE" # Logfile file descriptor
exec 1>&3 2>&3 # Redirect stdout and stderr to logfile

print_message() {
    local message="$1"
    local color="$2"

    if [ -n "$color" ]; then
        echo -e "${color}${message}${RESET}" >&4
    else
        echo "$message" >&4
    fi
    echo "$message"
}

abort() {
    local message="$1"
    local exit_code="${2:-1}"

    print_message "$message" "$YELLOW"
    print_message " "
    print_message "Log file created at '$LOG_FILE'" "$YELLOW"
    print_message " "
    print_message "Failed to install ProjectProto Lite" "$RED"
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
print_message "ProjectProto Lite 1.0 - microSD repartitioner"
print_message "for devices powered by MSM8916"
print_message "************************************************"
print_message "Do not remove your microSD card!" $RED
print_message " "

run init || abort "Failed to initialize environment" 255
run validation checkRequiredTools "$REQUIRED_TOOLS_LITE" || \
    abort "Recovery is missing required tools: $(getProperty missing_tools $PROP)" 127

# VALIDATION
print_message "· Validation"
print_message "-- Checking for platform compatibility"
run validation checkMSM8916Platform || abort "!! Unsupported platform. Aborting..."
print_message "-- MSM8916 platform detected"

print_message "-- Checking microSD card"
run utilities microSdCardAvailable || abort "!! No microSD card detected"
run validation checkMicroSdSizeLite || abort "!! Insufficient space on microSD card"

if run utilities projectProtoLiteInstalled; then
    print_message " "
    print_message "ProjectProto Lite is already installed" $GREEN
    print_message " "
    exit 0
fi

run utilities calculateMicroSdSize
print_message "-- microSD card size: $(getProperty microsd_total_size $PROP)"

print_message "-- Validation completed!"
print_message " "

# REPARTITIONER
print_message "· Repartitioner"
print_message "-- Unmounting microSD partitions"
run utilities unmountMicroSdPartitions || abort "!! Failed to unmount microSD partitions"

print_message "-- Repartitioning microSD card"
run repartitioner_lite repartitionMicroSdCardLite || abort "!! FATAL: Failed to repartition microSD card"

print_message "-- Formatting external partition as exFAT"
run repartitioner_lite formatExternalPartitionAsExFAT || abort "!! Failed to format external partition"

print_message "-- Formatting vendor partition as EXT4"
run repartitioner_lite formatVendorPartitionAsEXT4 || abort "!! Failed to format vendor partition"

print_message "-- Re-reading partition table from microSD card"
run utilities reReadMicroSdPartitionTable || abort "!! Failed to re-read partition table"
print_message "-- microSD card repartitioned successfully!"
print_message " "

# MISC
print_message "· Miscellaneous"
print_message "-- Calculating target partition sizes on microSD card"
if run utilities calculateMicroSdPartitionSizes "$PARTITIONS_LITE"; then
    print_message "   - External: $(getProperty microsd_external_size $PROP)"
    print_message "   - Vendor: $(getProperty microsd_vendor_size $PROP)"
fi

if ! run utilities mountMicroSdCardPartition vendor; then
    print_message "!! Failed to mount vendor partition from microSD card" $YELLOW
else
    print_message "-- Mounted vendor partition as /vendor_sdc2"
fi
print_message " "

if run utilities projectProtoLiteInstalled; then
    print_message "ProjectProto Lite installed successfully!" $GREEN
    print_message " "
    print_message "Note: Reboot to recovery to apply changes to the microSD card"
else
    print_message "ProjectProto Lite not properly installed!" $YELLOW
fi
print_message " "
