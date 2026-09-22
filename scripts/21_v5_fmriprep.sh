#!/bin/bash

#SBATCH --time=7:30:00
#SBATCH --ntasks-per-node=16
#SBATCH --cpus-per-task=1
#SBATCH --job-name=fmriprep
#SBATCH --account=def-amichaud
#SBATCH --mem=60000

# Optionally, uncomment and set for testing:
#export SUBJECT_NAME=RCX164

# Check if SUBJECT_NAME is provided
if [ -z "$SUBJECT_NAME" ]; then
  echo "Error: SUBJECT_NAME environment variable is not set."
  exit 1
fi

# Load modules
module load StdEnv/2023
module load apptainer fmriprep

# Use SUBJECT_NAME directly (provided via sbatch --export=SUBJECT_NAME=...)
subj="$SUBJECT_NAME"

# Specify hardware
nthreads=16  # Match the number of CPUs allocated
mem=56 # GB - Increased to 56GB for FreeSurfer + syn-SDC peak usage safety
omp_nthreads=8  # Maximum threads per process

# Convert virtual memory from GB to MB
mem_mb=$((mem*1000 - 1000)) # Larger buffer for syn-SDC processing

# File pathing
input_dir=${HOME}/projects/def-amichaud/share/GutBrain/data2
output_dir=${HOME}/projects/def-amichaud/share/GutBrain/derivatives4/fmriprep
work_dir=${SLURM_TMPDIR}
license_dir=${HOME}/projects/def-amichaud/share/GutBrain/fs_license

# Export paths - use Beluga-style paths
export APPTAINERENV_TEMPLATEFLOW_HOME=/tmp/templateflow
export APPTAINER_BIND=${input_dir}:/data,${output_dir}:/out,${license_dir}:/license,${work_dir}:/work,${HOME}/projects/def-amichaud/share/templateflow:/tmp/templateflow

# Run fmriprep
fmriprep /data /out participant \
 --skip_bids_validation \
 --work-dir /work \
 --participant-label ${subj} \
 --fs-license-file /license/license.txt \
 --nthreads ${nthreads} \
 --omp-nthreads ${omp_nthreads} \
 --mem_mb ${mem_mb} \
 --output-spaces MNI152NLin2009cAsym \
 #--use-syn-sdc \
 #--ignore fieldmaps \
 --notrack
