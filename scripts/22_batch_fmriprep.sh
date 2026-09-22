#!/bin/bash
# filepath: /home/pagag24/projects/def-amichaud/share/GutBrain/scripts/batch_fmriprep.sh

# Directory containing subject folders (e.g., sub-RGC901, sub-RGC902, etc.)
input_dir=${HOME}/projects/def-amichaud/share/GutBrain/data2

# Path to the fmriprep subject-level SLURM script
fmriprep_script=${HOME}/projects/def-amichaud/share/GutBrain/scripts/scripts_fmriprep/21_v5_fmriprep.sh

# Initialize counter for limiting to 4 participants (uncomment the next two lines to enable)
#count=0
#max_subjects=4

# Loop over all subject directories in input_dir
for subject_dir in "$input_dir"/*; do
  if [ -d "$subject_dir" ]; then
    # Uncomment the next 3 lines to limit to 4 participants
    #if [ $count -ge $max_subjects ]; then
    #  break
    #fi
    
    subject_name=$(basename "$subject_dir")
    echo "Submitting fmriprep job for subject: $subject_name"
    sbatch --export=SUBJECT_NAME="$subject_name" "$fmriprep_script"
    
    # Uncomment the next line to increment counter for 4-participant limit
    #((count++))
  fi
done
