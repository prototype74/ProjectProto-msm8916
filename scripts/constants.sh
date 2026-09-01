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

# =============================================================================
# Global constants
# =============================================================================
# PROP ......................... Path to installer property file
# PARTITIONS ................... Target partition order for iterations
# PARTITIONS_LITE .............. Target partition order for iterations (Lite)
# REQUIRED_TOOLS ............... Required tools
# REQUIRED_TOOLS_LITE .......... Required tools (Lite)
# VENDOR_SIZE_BYTES ............ Vendor partition size in bytes (700 MiB)
# DEV_BLOCK_EMMC ............... Internal storage block device
# DEV_BLOCK_MICROSD ............ microSD card block device
# DEV_BLOCK_PLATFORM_EMMC ...... Platform path to internal storage device
# DEV_BLOCK_PLATFORM_MICROSD ... Platform path to microSD card device
# DO NOT EDIT DEV BLOCK PATHS!
# =============================================================================
readonly PROP="/tmp/scripts/installer.prop"
readonly PARTITIONS="system cache hidden userdata vendor"
readonly PARTITIONS_LITE="external vendor"
readonly REQUIRED_TOOLS="dd sgdisk blockdev awk mke2fs"
readonly REQUIRED_TOOLS_LITE="sgdisk blockdev awk mkexfatfs mke2fs"
readonly VENDOR_SIZE_BYTES=$((1024 * 1024 * 700))
readonly DEV_BLOCK_EMMC="/dev/block/mmcblk0"
readonly DEV_BLOCK_MICROSD="/dev/block/mmcblk1"
readonly DEV_BLOCK_PLATFORM_EMMC="/dev/block/platform/soc.0/7824900.sdhci"
readonly DEV_BLOCK_PLATFORM_MICROSD="/dev/block/platform/soc.0/7864900.sdhci"
