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
    local current_date
    current_date=$(date +"%Y-%m-%d %H:%M:%S")

    if [ -f "$PROP" ]; then
        rm -f "$PROP" && echo "init: removed old properties"
    fi

    if ! touch "$PROP"; then
        echo "init: unable to generate properties" >&2
        exit 1
    fi

    echo "init: generating properties"

    echo "#Auto generated properties file" >> "$PROP"
    echo "#$current_date" >> "$PROP"
    echo "device_variant=unknown" >> "$PROP"

    chmod 0644 "$PROP"
    echo "init: properties generated successfully"
}

# MAIN FUNCTION
{
    echo "start init environment"
    printDeviceInformation
    generateProperties
    exit 0
}
