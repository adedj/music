#!/bin/bash

# Script to rename audio files (MP3, FLAC) based on metadata
# Format: Artist - Title.(extension)

# Create a temporary file to store counters
TEMP_COUNTERS=$(mktemp)

# Cleanup function to remove temporary files
function cleanup {
    rm -f "$TEMP_COUNTERS"
}
trap cleanup EXIT

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

MUSIC_DIR="deep house"
PREVIEW_MODE=true
FILE_TYPES="*.mp3 *.flac"

# Function to sanitize filenames
sanitize_filename() {
    local filename="$1"
    # Replace characters that are problematic in filenames
    filename="${filename//\//_}"    # Replace / with _
    filename="${filename//\\/_}"    # Replace \ with _
    filename="${filename//\?/_}"    # Replace ? with _
    filename="${filename//\*/_}"    # Replace * with _
    filename="${filename//\"/_}"    # Replace " with _
    filename="${filename//\:/_}"    # Replace : with _
    filename="${filename//\</_}"    # Replace < with _
    filename="${filename//\>/_}"    # Replace > with _
    filename="${filename//\|/_}"    # Replace | with _
    echo "$filename"
}

# Check if exiftool is installed
if ! command -v exiftool &> /dev/null; then
    echo -e "${RED}Error: exiftool is not installed. Please install it using your package manager.${NC}"
    exit 1
fi

echo -e "${BLUE}=== MP3 File Renaming Tool ===${NC}"
echo -e "${YELLOW}This tool will rename MP3 files based on their metadata.${NC}"
echo

# Count total files
total_files=$(find "$MUSIC_DIR" \( -name "*.mp3" -o -name "*.flac" \) | wc -l)
echo -e "${GREEN}Found $total_files audio files in '$MUSIC_DIR'${NC}"
echo

# Initialize counters in temporary file
echo "processed=0" > "$TEMP_COUNTERS"
echo "no_change=0" >> "$TEMP_COUNTERS"
echo "renamed=0" >> "$TEMP_COUNTERS"
echo "errors=0" >> "$TEMP_COUNTERS"
echo "would_rename=0" >> "$TEMP_COUNTERS"

# Process each audio file (MP3 and FLAC)
find "$MUSIC_DIR" \( -name "*.mp3" -o -name "*.flac" \) | while read -r file; do
    # Increment the processed counter
    processed=$(grep "^processed=" "$TEMP_COUNTERS" | cut -d= -f2)
    processed=$((processed + 1))
    sed -i "s/^processed=.*/processed=$processed/" "$TEMP_COUNTERS"
    
    # Extract artist and title from metadata
    artist=$(exiftool -s3 -Artist "$file" 2>/dev/null)
    title=$(exiftool -s3 -Title "$file" 2>/dev/null)
    
    # If metadata is missing, try to extract from filename
    if [[ -z "$artist" || -z "$title" ]]; then
        filename=$(basename "$file")
        extension="${filename##*.}"
        if [[ "$filename" =~ (.+)\ -\ (.+)\.(mp3|flac) ]]; then
            # If filename already has Artist - Title format, extract it
            if [[ -z "$artist" ]]; then
                artist="${BASH_REMATCH[1]}"
            fi
            if [[ -z "$title" ]]; then
                title="${BASH_REMATCH[2]}"
            fi
        fi
    fi
    
    # If we still don't have artist or title, skip this file
    if [[ -z "$artist" || -z "$title" ]]; then
        processed=$(grep "^processed=" "$TEMP_COUNTERS" | cut -d= -f2)
        echo -e "${RED}[$processed/$total_files] Error: Could not extract artist or title from '$file'${NC}"
        
        errors=$(grep "^errors=" "$TEMP_COUNTERS" | cut -d= -f2)
        errors=$((errors + 1))
        sed -i "s/^errors=.*/errors=$errors/" "$TEMP_COUNTERS"
        continue
    fi
    
    # Sanitize artist and title
    artist=$(sanitize_filename "$artist")
    title=$(sanitize_filename "$title")
    
    # Create new filename
    dir=$(dirname "$file")
    extension="${file##*.}"
    new_filename="$artist - $title.$extension"
    new_path="$dir/$new_filename"
    
    # Check if the file would change
    if [[ "$(basename "$file")" == "$new_filename" ]]; then
        processed=$(grep "^processed=" "$TEMP_COUNTERS" | cut -d= -f2)
        echo -e "${BLUE}[$processed/$total_files] No change needed: '$(basename "$file")'${NC}"
        
        no_change=$(grep "^no_change=" "$TEMP_COUNTERS" | cut -d= -f2)
        no_change=$((no_change + 1))
        sed -i "s/^no_change=.*/no_change=$no_change/" "$TEMP_COUNTERS"
        continue
    fi
    
    # Preview or perform the rename
    if [[ "$PREVIEW_MODE" == true ]]; then
        processed=$(grep "^processed=" "$TEMP_COUNTERS" | cut -d= -f2)
        echo -e "${YELLOW}[$processed/$total_files] Would rename:${NC}"
        echo -e "   ${RED}From:${NC} '$(basename "$file")'" 
        echo -e "   ${GREEN}To:${NC}   '$new_filename'"
        
        would_rename=$(grep "^would_rename=" "$TEMP_COUNTERS" | cut -d= -f2)
        would_rename=$((would_rename + 1))
        sed -i "s/^would_rename=.*/would_rename=$would_rename/" "$TEMP_COUNTERS"
    else
        processed=$(grep "^processed=" "$TEMP_COUNTERS" | cut -d= -f2)
        echo -e "${YELLOW}[$processed/$total_files] Renaming:${NC}"
        echo -e "   ${RED}From:${NC} '$(basename "$file")'" 
        echo -e "   ${GREEN}To:${NC}   '$new_filename'"
        
        if mv "$file" "$new_path"; then
            renamed=$(grep "^renamed=" "$TEMP_COUNTERS" | cut -d= -f2)
            renamed=$((renamed + 1))
            sed -i "s/^renamed=.*/renamed=$renamed/" "$TEMP_COUNTERS"
        else
            echo -e "${RED}Error renaming file!${NC}"
            errors=$(grep "^errors=" "$TEMP_COUNTERS" | cut -d= -f2)
            errors=$((errors + 1))
            sed -i "s/^errors=.*/errors=$errors/" "$TEMP_COUNTERS"
        fi
    fi
done

# Read final counter values
processed=$(grep "^processed=" "$TEMP_COUNTERS" | cut -d= -f2)
no_change=$(grep "^no_change=" "$TEMP_COUNTERS" | cut -d= -f2)
renamed=$(grep "^renamed=" "$TEMP_COUNTERS" | cut -d= -f2)
errors=$(grep "^errors=" "$TEMP_COUNTERS" | cut -d= -f2)
would_rename=$(grep "^would_rename=" "$TEMP_COUNTERS" | cut -d= -f2)

# Display summary
echo
echo -e "${BLUE}=== Summary ===${NC}"
echo -e "${YELLOW}Files processed:${NC} $processed"
if [[ "$PREVIEW_MODE" == true ]]; then
    echo -e "${YELLOW}Files that would be renamed:${NC} $would_rename"
else
    echo -e "${GREEN}Files renamed:${NC} $renamed"
fi
echo -e "${BLUE}Files already correctly named:${NC} $no_change"
echo -e "${RED}Errors:${NC} $errors"
echo

if [[ "$PREVIEW_MODE" == true ]]; then
    echo -e "${GREEN}This was a preview. To actually rename the files, run:${NC}"
    echo -e "${YELLOW}$0 apply${NC}"
else
    echo -e "${GREEN}Renaming complete!${NC}"
fi

# Check if we need to apply changes
if [[ "$1" == "apply" ]]; then
    echo -e "${GREEN}Applying changes...${NC}"
    PREVIEW_MODE=false
    # Recursive call to self with preview mode off
    "$0"
fi
