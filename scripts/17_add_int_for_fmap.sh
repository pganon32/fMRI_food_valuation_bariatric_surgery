#!/bin/bash

# This script adds the "IntendedFor" field to JSON files for susceptibility distortion correction.
# It processes multiple sessions (e.g., ses-1, ses-x, ses-2) in a BIDS dataset.

bids="$HOME/projects/def-amichaud/share/GutBrain/data2"  # Set the base BIDS directory here (e.g., "/path/to/bids")

echo "Starting to process BIDS dataset in: $bids"

# Loop through all subjects with sub* or one subject (example sub-RGC901)
for sub in "$bids"/sub*; do
    [ -d "$sub" ] || continue  # Skip if not a directory
    sub_name=$(basename "$sub")
    echo "Processing subject: $sub_name"

    # Loop through all sessions change for * or specific sessions
    for ses in "$sub"/ses-5; do
        [ -d "$ses" ] || continue  # Skip if not a directory
        ses_name=$(basename "$ses")
        echo "  Processing session: $ses_name"

	for fmap_json in "$ses/fmap/"*.json; do
   	   [ -f "$fmap_json" ] || continue  # Skip if not a file
    	   echo "    Clearing IntendedFor field in: $(basename "$fmap_json")"
    	   jq '.IntendedFor = (.IntendedFor // [])' "$fmap_json" > tmp.json && mv tmp.json "$fmap_json"
	done


        # Collect functional NIfTI files
        echo "    Collecting functional NIfTI files..."
        func_niis=()
        for func_file in "$ses"/func/*.nii*; do
            [ -f "$func_file" ] || continue  # Skip if not a file
            func_niis+=("${func_file#"$sub/"}")
        done
        echo "    Found ${#func_niis[@]} functional NIfTI files."

        # Process fMRI-related fmap JSON files
        echo "    Processing fmap JSON files..."
        for func_nii in "${func_niis[@]}"; do
            if [[ "$func_nii" == *"run-1"* ]]; then
                fmap_files=("$ses/fmap/"*run-1*_fieldmap.json "$ses/fmap/"*run-1*_magnitude.json)
            elif [[ "$func_nii" == *"run-2"* || "$func_nii" == *"run-3"* ]]; then
                fmap_files=("$ses/fmap/"*run-2*_fieldmap.json "$ses/fmap/"*run-2*_magnitude.json)
            else
                echo "      Skipping functional file: $func_nii (no matching fmap)"
                continue
            fi

            for fmap_func_json in "${fmap_files[@]}"; do
                [ -f "$fmap_func_json" ] || continue  # Skip if not a file
                echo "      Processing: $(basename "$fmap_func_json")"

                # Determine PhaseEncodingDirection based on PhaseEncodingAxis
                phase_encoding_axis=$(jq -r '.PhaseEncodingAxis // empty' "$fmap_func_json")
                if [[ "$phase_encoding_axis" == "j" ]]; then
                    phase_encoding_dir="j"
                elif [[ "$phase_encoding_axis" == "i" ]]; then
                    phase_encoding_dir="j"
                else
                    echo "      Skipping: $(basename "$fmap_func_json") (PhaseEncodingAxis not found or invalid)"
                    continue
                fi

                # Add IntendedFor and update PhaseEncodingDirection
                echo "      Updating IntendedFor and PhaseEncodingDirection in: $(basename "$fmap_func_json")"
                jq --arg intendedFor "$func_nii" \
                    --arg phaseEncodingDir "$phase_encoding_dir" \
                    '.IntendedFor += [$intendedFor] | .PhaseEncodingDirection = $phaseEncodingDir' \
                    "$fmap_func_json" > tmp.json && mv tmp.json "$fmap_func_json"
            done
        done
    done
done

echo "Finished processing BIDS dataset."
