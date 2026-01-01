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

readonly NAME="init"

# Print relevant debugging information
printDeviceInformation() {
    echo "Device information:"
    echo "- Platform:          $(getprop ro.board.platform)"
    echo "- Board:             $(getprop ro.product.board)"
    echo "- Bootloader:        $(getprop ro.boot.bootloader)"
    echo "- Model:             $(getprop ro.product.model)"
    echo "- Device:            $(getprop ro.product.device)"
    echo "- SoC manufacturer:  $(getprop ro.hardware)"
    echo "- TWRP version:      $(getprop ro.twrp.version)"
    echo "- TWRP fingerprint:  $(getprop ro.build.fingerprint)"
}

# Generate init properties
generateProperties() {
    local CURRENT_DATE=$(date +"%Y-%m-%d %H:%M:%S")

    if [ -f "$PROP" ]; then
        rm -f "$PROP" || {
            echo "$NAME: failed to remove old properties" >&2
            return 1
        }
        echo "$NAME: removed old properties"
    fi

    if ! touch "$PROP"; then
        echo "$NAME: unable to generate properties" >&2
        return 1
    fi

    echo "$NAME: generating properties"

    echo "#Auto generated properties file" >> "$PROP"
    echo "#$CURRENT_DATE" >> "$PROP"
    echo "device_variant=unknown" >> "$PROP"
    echo "microsd_total_size=0" >> "$PROP"
    echo "microsd_system_size=0" >> "$PROP"
    echo "microsd_cache_size=0" >> "$PROP"
    echo "microsd_hidden_size=0" >> "$PROP"
    echo "microsd_userdata_size=0" >> "$PROP"
    echo "microsd_vendor_size=0" >> "$PROP"

    chmod 0644 "$PROP"
    echo "$NAME: properties generated successfully"
    return 0
}

# MAIN FUNCTION
{
    echo "$NAME: start init environment"
    printDeviceInformation
    if ! generateProperties; then
        exit 1
    fi
    exit 0
}
