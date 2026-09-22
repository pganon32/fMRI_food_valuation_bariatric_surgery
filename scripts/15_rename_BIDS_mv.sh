#!/bin/bash

# Set the path to the data directory
dir=$HOME/projects/def-amichaud/share/GutBrain/data2

# Dynamically generate the list of subject IDs from the sourcedata directory

subject_ids=($(find "$HOME/projects/def-amichaud/share/GutBrain/data/sourcedata/" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort -V))

#subject_ids=("RND002")

# Function to extract AcquisitionTime from JSON file
get_acquisition_time() {
  local json_file=$1
  jq -r '.AcquisitionTime' "$json_file"
}

# Loop through each subject
for subject_id in "${subject_ids[@]}"; do
  name=$subject_id

  # Loop through sessions 1,2,3,4 and x
  for session in 5; do
    session_dir="$dir/sub-${name}/ses-${session}/"

    # Check if the session directory exists
    if [ -d "$session_dir" ]; then
      echo "Processing subject: $name"
      echo "Session: $session"

      # Check if the target directories exist, if not, create them
      for subdir in anat func fmap; do
        if [ ! -d "$session_dir$subdir" ]; then
          mkdir -p "$session_dir$subdir"
        fi
      done

      # Rename files (example for anat, func, and fmap)
      # Anat
      if ls $session_dir/*T1W_3D_TFE*.nii.gz 1> /dev/null 2>&1; then
        input_file=$(ls $session_dir/*T1W_3D_TFE*.nii.gz)
        json_file=$(ls $session_dir/*T1W_3D_TFE*.json)
        target_file=$session_dir/anat/sub-${name}_ses-${session}_T1w.nii.gz
        if [ ! -f "$target_file" ]; then
          mv $input_file $target_file
          mv $json_file $session_dir/anat/sub-${name}_ses-${session}_T1w.json
        fi
      fi

      # Func
      for run in 1 2 3; do
        if ls $session_dir/*FOOD${run}*.nii.gz 1> /dev/null 2>&1; then
          input_file=$(ls $session_dir/*FOOD${run}*.nii.gz)
          json_file=$(ls $session_dir/*FOOD${run}*.json)
          target_file=$session_dir/func/sub-${name}_ses-${session}_task-BDM_run-${run}_bold.nii.gz
          if [ ! -f "$target_file" ]; then
            mv $input_file $target_file
            mv $json_file $session_dir/func/sub-${name}_ses-${session}_task-BDM_run-${run}_bold.json
            sed -i '$s/}/,\n"TaskName":"BDM"}/' $session_dir/func/sub-${name}_ses-${session}_task-BDM_run-${run}_bold.json
          fi
        fi
      done

    # Fmap

    # Find the "a" labeled fmap json file
    a_fieldmap_json=$(ls $dir/sub-${name}/ses-${session}/*fieldmaphza.json)

    # Find the non "a" labeled fmap json file
    non_a_fieldmap_json=$(ls $dir/sub-${name}/ses-${session}/*fieldmaphz.json)

    # Find the "e1a" labeled fmap json file
    e1a_json=$(ls $dir/sub-${name}/ses-${session}/*e1a.json)

    # Find the non "e1a" labeled fmap json file
    e1_json=$(ls $dir/sub-${name}/ses-${session}/*e1.json)

    # Echo all file names
    echo "a_fieldmap_json: $a_fieldmap_json"
    echo "non_a_fieldmap_json: $non_a_fieldmap_json"
    echo "e1a_json: $e1a_json"
    echo "e1_json: $e1_json"

    # Get the acquisition times for the fmap files
    a_fieldmap_acq_time=$(get_acquisition_time "$a_fieldmap_json")
    non_a_fieldmap_acq_time=$(get_acquisition_time "$non_a_fieldmap_json")
    e1a_acq_time=$(get_acquisition_time "$e1a_json")
    e1_acq_time=$(get_acquisition_time "$e1_json")

    echo "Acquisition time for a_fieldmap: $a_fieldmap_acq_time"
    echo "Acquisition time for non_a_fieldmap: $non_a_fieldmap_acq_time"
    echo "Acquisition time for e1a: $e1a_acq_time"
    echo "Acquisition time for e1: $e1_acq_time"

    # Determine which fieldmap file to use for run 1 and 2
    if [[ "$non_a_fieldmap_acq_time" < "$a_fieldmap_acq_time" ]]; then
      run1_fieldmap_json=$non_a_fieldmap_json
      run1_fieldmap_nii=$(ls $dir/sub-${name}/ses-${session}/*fieldmaphz.nii.gz)
      run2_fieldmap_json=$a_fieldmap_json
      run2_fieldmap_nii=$(ls $dir/sub-${name}/ses-${session}/*fieldmaphza.nii.gz)
    else
      run1_fieldmap_json=$a_fieldmap_json
      run1_fieldmap_nii=$(ls $dir/sub-${name}/ses-${session}/*fieldmaphza.nii.gz)
      run2_fieldmap_json=$non_a_fieldmap_json
      run2_fieldmap_nii=$(ls $dir/sub-${name}/ses-${session}/*fieldmaphz.nii.gz)
    fi

    echo "Run 1 fieldmap NIfTI file: $run1_fieldmap_nii"
    echo "Run 1 fieldmap JSON file: $run1_fieldmap_json"
    echo "Run 2 fieldmap NIfTI file: $run2_fieldmap_nii"
    echo "Run 2 fieldmap JSON file: $run2_fieldmap_json"

    # Determine which magnitude file to use for run 1 and 2
    if [[ "$e1_acq_time" < "$e1a_acq_time" ]]; then
      run1_magnitude_json=$e1_json
      run1_magnitude_nii=$(ls $dir/sub-${name}/ses-${session}/*e1.nii.gz)
      run2_magnitude_json=$e1a_json
      run2_magnitude_nii=$(ls $dir/sub-${name}/ses-${session}/*e1a.nii.gz)
    else
      run1_magnitude_json=$e1a_json
      run1_magnitude_nii=$(ls $dir/sub-${name}/ses-${session}/*e1a.nii.gz)
      run2_magnitude_json=$e1_json
      run2_magnitude_nii=$(ls $dir/sub-${name}/ses-${session}/*e1.nii.gz)
    fi

    echo "Run 1 magnitude NIfTI file: $run1_magnitude_nii"
    echo "Run 1 magnitude JSON file: $run1_magnitude_json"
    echo "Run 2 magnitude NIfTI file: $run2_magnitude_nii"
    echo "Run 2 magnitude JSON file: $run2_magnitude_json"

    #   rename files
    if [ -f "$run1_fieldmap_nii" ]; then
      target_file=$dir/sub-${name}/ses-${session}/fmap/sub-${name}_ses-${session}_run-1_fieldmap.nii.gz
      if [ ! -f "$target_file" ]; then
        echo "  renaming $run1_fieldmap_nii to $target_file"
        mv $run1_fieldmap_nii $target_file
        mv $run1_fieldmap_json $dir/sub-${name}/ses-${session}/fmap/sub-${name}_ses-${session}_run-1_fieldmap.json
      fi
    else
      echo "Run 1 fieldmap NIfTI file not found: $run1_fieldmap_nii"
    fi

    if [ -f "$run1_magnitude_nii" ]; then
      target_file=$dir/sub-${name}/ses-${session}/fmap/sub-${name}_ses-${session}_run-1_magnitude.nii.gz
      if [ ! -f "$target_file" ]; then
        echo "  renaming $run1_magnitude_nii to $target_file"
        mv $run1_magnitude_nii $target_file
        mv $run1_magnitude_json $dir/sub-${name}/ses-${session}/fmap/sub-${name}_ses-${session}_run-1_magnitude.json
      fi
    else
      echo "Run 1 magnitude NIfTI file not found: $run1_magnitude_nii"
    fi

    if [ -f "$run2_fieldmap_nii" ]; then
      target_file=$dir/sub-${name}/ses-${session}/fmap/sub-${name}_ses-${session}_run-2_fieldmap.nii.gz
      if [ ! -f "$target_file" ]; then
        echo "  renaming $run2_fieldmap_nii to $target_file"
        mv $run2_fieldmap_nii $target_file
        mv $run2_fieldmap_json $dir/sub-${name}/ses-${session}/fmap/sub-${name}_ses-${session}_run-2_fieldmap.json
      fi
    else
      echo "Run 2 fieldmap NIfTI file not found: $run2_fieldmap_nii"
    fi
    if [ -f "$run2_magnitude_nii" ]; then
      target_file=$dir/sub-${name}/ses-${session}/fmap/sub-${name}_ses-${session}_run-2_magnitude.nii.gz
      if [ ! -f "$target_file" ]; then
        echo "  renaming $run2_magnitude_nii to $target_file"
        mv $run2_magnitude_nii $target_file
        mv $run2_magnitude_json $dir/sub-${name}/ses-${session}/fmap/sub-${name}_ses-${session}_run-2_magnitude.json
      fi
    else
      echo "Run 2 magnitude NIfTI file not found: $run2_magnitude_nii"
    fi

      # Count the number of .nii.gz and .json files in each directory
      func_nii_count=$(find $dir/sub-${name}/ses-${session}/func -maxdepth 1 -name "*.nii.gz" 2>/dev/null | wc -l)
      func_json_count=$(find $dir/sub-${name}/ses-${session}/func -maxdepth 1 -name "*.json" 2>/dev/null | wc -l)
      anat_nii_count=$(find $dir/sub-${name}/ses-${session}/anat -maxdepth 1 -name "*.nii.gz" 2>/dev/null | wc -l)
      anat_json_count=$(find $dir/sub-${name}/ses-${session}/anat -maxdepth 1 -name "*.json" 2>/dev/null | wc -l)
      fmap_nii_count=$(find $dir/sub-${name}/ses-${session}/fmap -maxdepth 1 -name "*.nii.gz" 2>/dev/null | wc -l)
      fmap_json_count=$(find $dir/sub-${name}/ses-${session}/fmap -maxdepth 1 -name "*.json" 2>/dev/null | wc -l)

      # Check if the counts match the expected values
      if [ "$func_nii_count" -eq 3 ] && [ "$func_json_count" -eq 3 ] &&
         [ "$anat_nii_count" -eq 1 ] && [ "$anat_json_count" -eq 1 ] &&
         [ "$fmap_nii_count" -eq 4 ] && [ "$fmap_json_count" -eq 4 ]; then
        echo "All files are correctly placed for session ${session}. Removing files from the directory above."
        # Uncomment the following lines to enable file removal
        find $dir/sub-${name}/ses-${session} -maxdepth 1 -name "*.nii.gz" -exec rm {} \;
        find $dir/sub-${name}/ses-${session} -maxdepth 1 -name "*.json" -exec rm {} \;
      else
        echo "File counts do not match the expected values for session ${session}. No files will be removed."
      fi



    else
      echo "Directory $session_dir does not exist. Skipping."
    fi
  done
done


