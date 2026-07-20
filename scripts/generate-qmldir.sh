#!/bin/bash
# generate-qmldir.sh — auto-generate qmldir for a QML module directory.
#
# Usage: generate-qmldir.sh <directory> <module-name>
#
# Scans all .qml files in the directory, detects pragma Singleton,
# and writes a qmldir with proper singleton declarations.
#
# Example:
#   ./scripts/generate-qmldir.sh quickshell/services qs.services
#   ./scripts/generate-qmldir.sh ~/development/sumika-modules/popup-components qs.modules.popup-components

set -eu

dir="$1"
module_name="$2"

if [ ! -d "$dir" ]; then
    echo "Error: directory '$dir' does not exist" >&2
    exit 1
fi

qml_files=$(find "$dir" -maxdepth 1 -name "*.qml" -type f 2>/dev/null)

if [ -z "$qml_files" ]; then
    # No QML files — still write a minimal qmldir (module declaration only)
    echo "module $module_name" > "$dir/qmldir"
    echo "Generated minimal qmldir for $module_name (no QML files found)"
    exit 0
fi

# Write qmldir
{
    echo "module $module_name"
    for f in $qml_files; do
        name=$(basename "$f" .qml)
        filename=$(basename "$f")
        if grep -q "pragma Singleton" "$f" 2>/dev/null; then
            echo "singleton $name 1.0 $filename"
        else
            echo "$name 1.0 $filename"
        fi
    done
} > "$dir/qmldir"

echo "Generated $dir/qmldir for module $module_name ($(echo "$qml_files" | wc -l) components)"
cat "$dir/qmldir"