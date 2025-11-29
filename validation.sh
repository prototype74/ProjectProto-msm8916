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

{
    if type "$1" >/dev/null 2>&1; then
        "$1"
        exit $?
    else
        echo "Function $1 not found" >&2
        exit 1
    fi
}
