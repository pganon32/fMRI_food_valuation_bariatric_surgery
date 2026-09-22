#!/bin/bash

# Usage: ./slice_info_json.sh [--force] [--verbose] [SESSION] [SUBJECT1] [SUBJECT2] ...
# Example: ./slice_info_json.sh 5 RND032
# Example: ./slice_info_json.sh --verbose "" RND014 RND015 RND016
# Example: ./slice_info_json.sh --force --verbose 5 RND032
# Example: ./slice_info_json.sh --force "" RND014 RND015

# Parse arguments
FORCE=false
VERBOSE=false

while [[ "$1" == --* ]]; do
    case "$1" in
        --force) FORCE=true; shift ;;
        --verbose) VERBOSE=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

SESSION="$1"
shift

SUBJECTS=("$@")

# Define the directory containing the BIDS dataset 
bids_dir="$HOME/projects/def-amichaud/share/GutBrain/data2"

# Define the SliceTiming field with 59.78260 ms increments for exactly 45 points
slice_timing=$(awk 'BEGIN { for (i = 0; i < 45; i++) printf "%.8f,", i * 0.05978260; printf "\n" }' | sed 's/,$//')

# Build find pattern based on arguments
if [[ ${#SUBJECTS[@]} -eq 0 ]]; then
    # No subjects specified
    if [[ -n "$SESSION" ]]; then
        # Session specified but no subjects - search all subjects for that session
        find_pattern="$bids_dir/*/ses-${SESSION}"
    else
        # No session, no subjects - process everything
        find_pattern="$bids_dir"
    fi
else
    # Build pattern for specific subjects
    find_pattern=""
    for subject in "${SUBJECTS[@]}"; do
        if [[ -n "$SESSION" ]]; then
            find_pattern+=" $bids_dir/sub-${subject}/ses-${SESSION}"
        else
            find_pattern+=" $bids_dir/sub-${subject}"
        fi
    done
fi

# Traverse the BIDS directory
if [[ -z "$find_pattern" ]]; then
    find_pattern="$bids_dir"
fi

find $find_pattern -type f -name "*bold.json" 2>/dev/null | while read -r json_file; do
    # Debug: Print the current JSON file being processed
    echo "Processing: $json_file"

    # Check if file should be skipped (if not --force and fields already exist)
    if [[ "$FORCE" == false ]]; then
        if jq -e '.SliceTiming? // empty' "$json_file" > /dev/null 2>&1 && \
           jq -e '.PhaseEncodingDirection? // empty' "$json_file" > /dev/null 2>&1; then
            echo "Skipping (already processed): $json_file (use --force to override)"
            
            if [[ "$VERBOSE" == true ]]; then
                echo "  Existing fields:"
                phase_enc_dir=$(jq -r '.PhaseEncodingDirection // "Not found"' "$json_file")
                total_readout=$(jq -r '.TotalReadoutTime // "Not found"' "$json_file")
                slice_count=$(jq -r '.SliceTiming | length' "$json_file" 2>/dev/null || echo "Not found")
                echo "    PhaseEncodingDirection: $phase_enc_dir"
                echo "    TotalReadoutTime: $total_readout"
                echo "    SliceTiming points: $slice_count"
            fi
            continue
        fi
    fi

    # Extract the PhaseEncodingAxis from the JSON file
    phase_encoding_axis=$(jq -r '.PhaseEncodingAxis // empty' "$json_file")

    if [[ "$VERBOSE" == true ]]; then
        echo "  Before modification:"
        echo "    PhaseEncodingAxis: ${phase_encoding_axis:-Not found}"
        est_readout=$(jq -r '.EstimatedTotalReadoutTime // "Not found"' "$json_file")
        echo "    EstimatedTotalReadoutTime: $est_readout"
    fi

    # Determine PhaseEncodingDirection based on PhaseEncodingAxis
    case "$phase_encoding_axis" in
        "i") phase_encoding_direction="j" ;;
        "j") phase_encoding_direction="j" ;;
        "k") phase_encoding_direction="k" ;;
        *) 
            echo "Warning: Invalid or missing PhaseEncodingAxis in $json_file. Skipping."
            continue
            ;;
    esac

    # Check if EstimatedTotalReadoutTime exists and rename it to TotalReadoutTime
    if jq -e '.EstimatedTotalReadoutTime? // empty' "$json_file" > /dev/null; then
        temp_file=$(mktemp)
        jq '.TotalReadoutTime = .EstimatedTotalReadoutTime | del(.EstimatedTotalReadoutTime)' "$json_file" > "$temp_file" && mv "$temp_file" "$json_file"
        if [[ $? -eq 0 ]]; then
            echo "Renamed EstimatedTotalReadoutTime to TotalReadoutTime in: $json_file"
        else
            echo "Failed to rename EstimatedTotalReadoutTime in: $json_file"
        fi
    fi

    # Extract participant and session information from the path
    participant=$(echo "$json_file" | grep -oP "sub-\K[^/]+" | head -1)
    session=$(echo "$json_file" | grep -oP "ses-\K[^/]+" | head -1)

    # Debug: Print participant and session information
    echo "Participant: ${participant:-Unknown}, Session: ${session:-Unknown}"

    # Load the JSON file and add the new fields
    temp_file=$(mktemp)
    jq --argjson sliceTiming "[$slice_timing]" \
       --arg PhaseEncodingDirection "$phase_encoding_direction" \
       '.SliceTiming = $sliceTiming | .PhaseEncodingDirection = $PhaseEncodingDirection' \
       "$json_file" > "$temp_file" && mv "$temp_file" "$json_file"

    # Check if jq succeeded
    if [[ $? -eq 0 ]]; then
        echo "Updated: $json_file"
    else
        echo "Failed to update: $json_file"
    fi

    # Make sure t1s and fmap .jsons don't have SliceTiming and SliceEncodingDirection
    if [[ "$json_file" != *"bold"* ]]; then
        jq 'del(.SliceTiming, .PhaseEncodingDirection)' "$json_file" > "$temp_file" && mv "$temp_file" "$json_file"
        if [[ $? -eq 0 ]]; then
            echo "Removed SliceTiming and PhaseEncodingDirection from: $json_file"
        else
            echo "Failed to remove SliceTiming and PhaseEncodingDirection from: $json_file"
        fi
    fi

    # Check if PhaseEncodingDirection exists and has a value
    if jq -e '.PhaseEncodingDirection? // empty' "$json_file" > /dev/null; then
        # Remove PhaseEncodingAxis if PhaseEncodingDirection exists and has a value
        jq 'del(.PhaseEncodingAxis)' "$json_file" > "$temp_file" && mv "$temp_file" "$json_file"
        if [[ $? -eq 0 ]]; then
            echo "Removed PhaseEncodingAxis from: $json_file"
        else
            echo "Failed to remove PhaseEncodingAxis from: $json_file"
        fi
    fi

    # Verbose output: Show final state
    if [[ "$VERBOSE" == true ]]; then
        echo "  After modification:"
        phase_enc_dir=$(jq -r '.PhaseEncodingDirection // "Not found"' "$json_file")
        total_readout=$(jq -r '.TotalReadoutTime // "Not found"' "$json_file")
        slice_count=$(jq -r '.SliceTiming | length' "$json_file" 2>/dev/null || echo "0")
        echo "    PhaseEncodingDirection: $phase_enc_dir"
        echo "    TotalReadoutTime: $total_readout"
        echo "    SliceTiming points: $slice_count"
        echo "    PhaseEncodingAxis: Removed"
    fi

done

echo "All JSON files updated successfully."
