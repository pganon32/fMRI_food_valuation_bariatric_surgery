#!/bin/bash
#SBATCH --job-name=MRIQC_group
#SBATCH --output=MRIQC_group_%j_.out
#SBATCH --error=MRIQC_group_%j_.err
#SBATCH --time=00:30:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=60G

echo "Loading the necessary module..."
module load apptainer/1.3.5

# Parse command line arguments for direct execution
# Example: sbatch mriqc_group.sh
# Example: sbatch mriqc_group.sh RND050
# Example: sbatch mriqc_group.sh RND050 5
# Example: sbatch mriqc_group.sh "" 5  # All subjects, session 5 only
# Example: sbatch --export=SUBJECT_NAME=sub-RND050,SESSION=5 mriqc_group.sh

# Check if arguments were passed directly
if [ $# -gt 0 ]; then
    SUBJECT_NAME="$1"
    SESSION="${2:-}"  # Optional second argument for session
fi

# Build participant label filter if SUBJECT_NAME is specified and not empty
PARTICIPANT_FILTER=""
if [ -n "$SUBJECT_NAME" ]; then
    # Strip 'sub-' prefix if present for MRIQC
    SUBJECT_ID=${SUBJECT_NAME#sub-}
    echo "Processing subject: $SUBJECT_ID"
    PARTICIPANT_FILTER="--participant-label $SUBJECT_ID"
else
    echo "Processing all subjects"
fi

# Build session filter if SESSION is specified
SESSION_FILTER=""
if [ -n "$SESSION" ]; then
    echo "Filtering for session: $SESSION"
    SESSION_FILTER="--session-id $SESSION"
fi

# Define paths
input_dir=/home/pagag24/projects/def-amichaud/share/GutBrain/data2
output_dir=/home/pagag24/projects/def-amichaud/share/GutBrain/derivatives4/mriqc
CONTAINER_IMAGE=/home/pagag24/myimages/mriqc-24.0.2.sif

# Echo all of the directories
echo "Input directory: $input_dir"
echo "Output directory: $output_dir"
echo "Container image: $CONTAINER_IMAGE"
echo "Participant filter: $PARTICIPANT_FILTER"
echo "Session filter: $SESSION_FILTER"

# Set TMPDIR based on environment (interactive vs batch)
if [ -z "$SLURM_TMPDIR" ]; then
    echo "Running in interactive mode - using /tmp"
    TMPDIR=/tmp/mriqc_tmp_$$
    mkdir -p $TMPDIR
else
    echo "Running in SLURM batch mode"
    TMPDIR=$SLURM_TMPDIR
fi

mkdir -p $TMPDIR/HZ_tmp
apptainer run -C -W $TMPDIR \
     --writable-tmpfs \
     -B /home/pagag24/projects/def-amichaud/share/GutBrain:/GutBrain \
     -B $TMPDIR \
     -B $TMPDIR/HZ_tmp:/tmp \
     $CONTAINER_IMAGE \
     /GutBrain/data2 /GutBrain/derivatives4/mriqc group \
     $PARTICIPANT_FILTER \
     $SESSION_FILTER \
     --work-dir $TMPDIR/HZ_tmp \
     --n_procs 4  \
     --mem_gb 55 \
     --no-sub \
     --bids-database-wipe

# Cleanup if using /tmp
if [ -z "$SLURM_TMPDIR" ]; then
    rm -rf $TMPDIR
fi

echo "MRIQC group processing complete."
