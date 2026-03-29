#!/bin/bash

# Configuration
START=187
END=336
BASE_VER="v4.14"

echo "Starting upstreaming process from ${BASE_VER}.${START} to ${BASE_VER}.${END}"

# Find the last merged version to resume if needed
LAST_MERGED=$(git log -1 --grep="Merge v4.14." --oneline | grep -o 'v4.14.[0-9]*' | awk -F. '{print $3}')
if [ -n "$LAST_MERGED" ] && [ "$LAST_MERGED" -ge "$START" ]; then
    NEXT=$((LAST_MERGED + 1))
    echo "Detected last merged version: ${BASE_VER}.${LAST_MERGED}"
    echo "Resuming from ${BASE_VER}.${NEXT}..."
    START=$NEXT
fi

if [ "$START" -gt "$END" ]; then
    echo "Upstreaming complete! Reached $END."
    exit 0
fi

# Check for uncommitted changes
if ! git diff-index --quiet HEAD --; then
    echo "ERROR: You have uncommitted changes. Please commit or stash them before running this script."
    echo "If you just resolved a conflict, please commit it using: git commit -m \"Merge ${BASE_VER}.X\""
    exit 1
fi

for ((i=START; i<=END; i++)); do
    PREV=$((i - 1))
    
    echo ""
    echo "======================================================"
    echo " Upstreaming ${BASE_VER}.${PREV} -> ${BASE_VER}.${i}"
    echo "======================================================"
    
    # 1. Generate patch
    PATCH_FILE="temp_upstream_${i}.patch"
    echo "Generating patch..."
    git diff ${BASE_VER}.${PREV} ${BASE_VER}.${i} > "$PATCH_FILE"
    
    # 2. Apply patch with 3-way fallback
    echo "Applying patch..."
    git apply -3 "$PATCH_FILE"
    APPLY_STATUS=$?
    
    # 3. IMMEDIATELY remove the patch file so it doesn't linger
    rm -f "$PATCH_FILE"
    # Also clean up any .orig or .rej files that might have been created
    find . -name "*.rej" -type f -delete
    find . -name "*.orig" -type f -delete
    
    # 4. Check for success
    if [ $APPLY_STATUS -eq 0 ]; then
        echo "Patch applied cleanly. Committing..."
        git add .
        git commit -m "Merge ${BASE_VER}.${i}"
    else
        echo "======================================================"
        echo " CONFLICT DETECTED while applying ${BASE_VER}.${i}"
        echo "======================================================"
        echo "The script has automatically removed the .patch files."
        echo "Please do the following:"
        echo "  1. Search for '<<<<<<<' in your files to find the conflicts."
        echo "  2. Resolve the conflicts manually."
        echo "  3. Run: git add ."
        echo "  4. Run: git commit -m \"Merge ${BASE_VER}.${i}\""
        echo "  5. Re-run this script (./upstream.sh) to continue to the next version."
        exit 1
    fi
done

echo "Successfully reached ${BASE_VER}.${END}!"
