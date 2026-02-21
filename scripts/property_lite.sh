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

# Get property value from a key in a properties file.
#
# Arguments:
#   $1 (string): Key to search for.
#   $2 (path):   Path to the file (e.g. /vendor/build.prop).
#
# Notes:
#   - Supports dots or other separators in the key name.
#   - Returns the property value if found, or empty string if not found
getProperty() {
    local key=$1
    local file=$2
    local value

    value=$(grep -m1 "^${key}=" "$file" 2>/dev/null | cut -d'=' -f2-)
    [ -n "$value" ] && echo "$value" || echo ""
}

# Update a property value in a properties file.
#
# Arguments:
#   $1 (string): Key to search for.
#   $2 (string): New value.
#   $3 (path):   Path to file (e.g. /vendor/build.prop)
#
# Notes:
#   - Do not use "=" or "/" in key/value (they break sed syntax).
#   - If the key does not exist, prints a warning message.
updateProperty() {
    local property_key=$1
    local new_property_value=$2
    local file=$3

    if grep -q "^${property_key}=" "$file"; then
        sed -i "s/^${property_key}=.*/${property_key}=${new_property_value}/" "$file"
    else
        printf "updateProperty: key '%s' not found in '%s'\n" "$property_key" "$file" >&2
    fi
}
