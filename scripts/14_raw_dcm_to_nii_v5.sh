#!/bin/bash
#SBATCH --account=def-amichaud
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=5000M
#SBATCH --time=0-00:5           # time (DD-HH:MM) ~10min/participant
#SBATCH --job-name="BIDS convert"


# Create a directory for SLURM output and error files in $SCRATCH
scratch_dir="$SCRATCH/slurm_logs"
mkdir -p "$scratch_dir"

# Specify output and error file locations
#SBATCH --output="$scratch_dir/%x_%j.out"
#SBATCH --error="$scratch_dir/%x_%j.err"

# Array for all RGCs : 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,19,20,21,24,25
#This script converts all DICOM files from data/sourcedata/* to nifti or json with dcm2niix, 
# Usage: ./raw_dcm_to_nii_v2.sh [--force] [SESSION] [SUBJECT1] [SUBJECT2] ...
# Example: ./raw_dcm_to_nii_v2.sh BL RND014
# Example: ./raw_dcm_to_nii_v2.sh "" RND014 RND015 RND016
# Example: ./raw_dcm_to_nii_v2.sh --force BL RND014
# Example: ./raw_dcm_to_nii_v2.sh --force "" RND014 RND015

module load dcm2niix/1.0.20230411

# Define input and output directories
input_dir=~/projects/def-amichaud/share/GutBrain/data
output_dir=~/projects/def-amichaud/share/GutBrain/data2

# Check for --force flag
FORCE=false
if [[ "$1" == "--force" ]]; then
  FORCE=true
  shift
  echo "Force mode enabled: Will overwrite existing NIfTI files"
fi

# Optional: Specify session(s) to process (e.g., "60M", "24M", "12M", "4M", "BL")
# Leave empty to process all sessions
SESSION="${1:-}"  # First argument, empty if not provided

# Collect subject IDs from remaining arguments
shift  # Remove first argument (session)
SUBJECTS=("$@")  # Remaining arguments are subject IDs

if [ -n "$SESSION" ]; then
  echo "Processing session: $SESSION"
else
  echo "Processing all sessions"
fi

if [ ${#SUBJECTS[@]} -gt 0 ]; then
  echo "Processing specific subjects: ${SUBJECTS[*]}"
else
  echo "Processing all subjects"
fi

# Initialize counter for valid subjects
valid_count=0

# Loop through each subject directory
for subject_dir in "$input_dir/sourcedata"/*; do
  if [ -d "$subject_dir" ]; then
    # Extract subject name
    name=$(basename "$subject_dir")
    
    # If specific subjects were provided, check if this one is in the list
    if [ ${#SUBJECTS[@]} -gt 0 ]; then
      subject_found=false
      for subj in "${SUBJECTS[@]}"; do
        if [[ "$name" == "$subj" ]]; then
          subject_found=true
          break
        fi
      done
      if [ "$subject_found" = false ]; then
        continue  # Skip this subject
      fi
    fi
    
    # Skip if this directory doesn't have a DICOM subdirectory
    if [ ! -d "$subject_dir/DICOM" ]; then
      continue
    fi
    
    # Increment valid subject counter
    ((valid_count++))
    
    echo ""
    echo "=========================================="
    echo "[$valid_count] Processing subject: $name"
    echo "=========================================="
    
    # Determine which sessions to process
    if [ -n "$SESSION" ]; then
      # Process only the specified session
      session_dirs="$subject_dir/DICOM/$SESSION"
      if [ ! -d "$session_dirs" ]; then
        echo "Session $SESSION not found for subject $name. Skipping."
        continue
      fi
    else
      # Process all sessions
      session_dirs="$subject_dir/DICOM"/*
    fi
    
    # Loop through sessions for this subject
    for session_path in $session_dirs; do
      if [ ! -d "$session_path" ]; then
        continue
      fi
      
      # Extract session name from path
      ses=$(basename "$session_path")
      
      # Map session names to numbers
      if [[ ${ses} = 'BL' ]]; then
        session=1
      elif [[ ${ses} = '4M' ]]; then
        session=2
      elif [[ ${ses} = '12M' ]]; then
        session=3
      elif [[ ${ses} = '24M' ]]; then
        session=4
      elif [[ ${ses} = '60M' ]]; then
        session=5
      else
        echo "Unknown session: $ses. Skipping."
        continue
      fi
      
      echo "  Processing session: $ses (session $session)"
      
      # Create output directory if it doesn't exist
      if [ ! -d "$output_dir/sub-${name}/ses-${session}" ]; then
        mkdir -p "$output_dir/sub-${name}/ses-${session}"/{anat,func,fmap}
      fi
      
      # Check if NIfTI files already exist (unless force mode is enabled)
      if [ "$FORCE" = false ] && find "$output_dir/sub-${name}/ses-${session}" -maxdepth 2 -type f -name "*.nii.gz" | grep -q .; then
        echo "  NIfTI files already exist for subject $name, session $ses. Skipping conversion."
      else
        if [ "$FORCE" = true ]; then
          echo "  Force mode: Overwriting existing files..."
        else
          echo "  No existing NIfTI files found. Starting conversion..."
        fi
        dcm2niix -o "$output_dir/sub-${name}/ses-${session}" -b y -m y -z y -p y -s y -f sub-%i_%t_%p "$session_path/"
        echo "  Conversion complete for $name, session $ses"
      fi
    done
  fi
done

echo ""
echo "=========================================="
echo "Processing complete! Total subjects processed: $valid_count"
echo "=========================================="
