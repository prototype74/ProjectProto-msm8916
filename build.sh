#!/bin/bash
#
# Copyright (c) 2026 prototype74
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

set -e

SCRIPT_DIR="$(pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
VERSION="full"

SCRIPTS_COMMON=(
    "constants.sh"
    "helpers.sh"
    "init.sh"
    "property_lite.sh"
    "utilities.sh"
    "validation.sh"
)

# Scripts only for regular version
SCRIPTS_FULL=(
    "cloner.sh"
    "install.sh"
    "repartitioner.sh"
)

# Scripts only for lite version
SCRIPTS_LITE=(
    "install_lite.sh"
    "repartitioner_lite.sh"
)

build_zip() {
    local version="$1"
    local zip_name
    local meta_inf_src
    local scripts=("${SCRIPTS_COMMON[@]}")

    if [ "$version" = "lite" ]; then
        zip_name="ProjectProto-lite.zip"
        meta_inf_src="$SCRIPT_DIR/META-INF-lite"
        scripts+=("${SCRIPTS_LITE[@]}")
    else
        zip_name="ProjectProto.zip"
        meta_inf_src="$SCRIPT_DIR/META-INF"
        scripts+=("${SCRIPTS_FULL[@]}")
    fi

    echo "Building $zip_name..."

    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR/scripts"

    cp -r "$meta_inf_src" "$BUILD_DIR/META-INF"

    for script in "${scripts[@]}"; do
        if [ -f "$SCRIPT_DIR/scripts/$script" ]; then
            cp "$SCRIPT_DIR/scripts/$script" "$BUILD_DIR/scripts/"
        else
            echo "ERROR: Script not found: $script" >&2
            rm -rf "$BUILD_DIR"
            exit 1
        fi
    done

    cp "$SCRIPT_DIR/LICENSE" "$BUILD_DIR/"

    (cd "$BUILD_DIR" && zip -r "$SCRIPT_DIR/$zip_name" .)

    rm -rf "$BUILD_DIR"

    echo "Done: $zip_name"
}

if [ "$1" = "lite" ]; then
    VERSION="lite"
fi

build_zip "$VERSION"
