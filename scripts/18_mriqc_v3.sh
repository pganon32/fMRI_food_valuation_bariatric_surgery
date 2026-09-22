#!/bin/bash
#SBATCH --job-name=MRIQC
#SBATCH --output=MRIQC_%j_.out
#SBATCH --error=MRIQC_%j_.err
#SBATCH --time=01:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=60G

echo "Loading the necessary module..."
module load apptainer

# Parse command line arguments for direct execution
# Example: sbatch mriqc_v3.sh RND050
# Example: sbatch mriqc_v3.sh RND050 5
# Example: sbatch --export=SUBJECT_NAME=sub-RND050,SESSION=5 mriqc_v3.sh

# Check if arguments were passed directly
if [ $# -gt 0 ]; then
    SUBJECT_NAME="$1"
    SESSION="${2:-}"  # Optional second argument for session
elif [ -z "$SUBJECT_NAME" ]; then
    # For testing, uncomment the line below
    #SUBJECT_NAME='sub-RND050'
    #SESSION='5'
    
    echo "Error: SUBJECT_NAME not provided."
    echo "Usage: sbatch mriqc_v3.sh <subject> [session]"
    echo "   OR: sbatch --export=SUBJECT_NAME=sub-RND050[,SESSION=5] mriqc_v3.sh"
    exit 1
fi

# Strip 'sub-' prefix if present for MRIQC
SUBJECT_ID=${SUBJECT_NAME#sub-}
echo "Processing subject: $SUBJECT_ID"

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

mkdir $SLURM_TMPDIR/HZ_tmp
apptainer run -C -W $SLURM_TMPDIR \
     --writable-tmpfs \
     -B /home/pagag24/projects/def-amichaud/share/GutBrain:/GutBrain \
     -B $SLURM_TMPDIR \
     -B $SLURM_TMPDIR/HZ_tmp:/tmp \
     $CONTAINER_IMAGE \
     /GutBrain/data2 /GutBrain/derivatives4/mriqc  participant \
     --participant-label $SUBJECT_ID \
     $SESSION_FILTER \
     --work-dir $SLURM_TMPDIR/HZ_tmp \
     --n_procs 4  \
     --mem_gb 55 \
     --no-sub \
     --bids-database-wipe

echo "MRIQC processing complete."
