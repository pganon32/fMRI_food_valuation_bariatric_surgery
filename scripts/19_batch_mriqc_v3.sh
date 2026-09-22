#!/bin/bash

# Batch submission script for MRIQC
# Usage examples:
#   ./batch_mriqc.sh                           # All subjects, all sessions
#   ./batch_mriqc.sh --session 5               # All subjects, session 5 only
#   ./batch_mriqc.sh --subjects RND050 RND051  # Specific subjects, all sessions
#   ./batch_mriqc.sh --subjects RND050 --session 5  # Specific subjects and session

# Parse arguments
SESSION=""
SUBJECTS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --session)
            SESSION="$2"
            shift 2
            ;;
        --subjects)
            shift
            while [[ $# -gt 0 && ! "$1" =~ ^-- ]]; do
                SUBJECTS+=("$1")
                shift
            done
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--session <num>] [--subjects <sub1> <sub2> ...]"
            exit 1
            ;;
    esac
done

# Define the input directory
input_dir=~/projects/def-amichaud/share/GutBrain/data2/

# If no specific subjects provided, get all subjects from directory
if [ ${#SUBJECTS[@]} -eq 0 ]; then
    echo "No specific subjects provided. Processing all subjects in $input_dir"
    for subject_dir in "$input_dir"/sub-*; do
        if [ -d "$subject_dir" ]; then
            subject_name=$(basename "$subject_dir")
            SUBJECTS+=("$subject_name")
        fi
    done
fi

# Display what will be processed
echo "======================================"
echo "Batch MRIQC Submission"
echo "======================================"
echo "Number of subjects to check: ${#SUBJECTS[@]}"
if [ -n "$SESSION" ]; then
    echo "Session filter: $SESSION"
else
    echo "Session filter: None (all sessions)"
fi
echo "======================================"

# Submit jobs
submitted_count=0
skipped_count=0

for subject_name in "${SUBJECTS[@]}"; do
    # Ensure subject has 'sub-' prefix
    if [[ ! "$subject_name" =~ ^sub- ]]; then
        subject_name="sub-$subject_name"
    fi
    
    # Check if session exists when session filter is specified
    if [ -n "$SESSION" ]; then
        session_dir="$input_dir/$subject_name/ses-$SESSION"
        if [ ! -d "$session_dir" ]; then
            echo "Skipping $subject_name: ses-$SESSION does not exist"
            ((skipped_count++))
            continue
        fi
        
        echo "Submitting job for subject: $subject_name, session: $SESSION"
        sbatch --export=SUBJECT_NAME="$subject_name",SESSION="$SESSION" \
            $HOME/projects/def-amichaud/share/GutBrain/scripts/scripts_mriqc/mriqc_v3.sh
        ((submitted_count++))
    else
        echo "Submitting job for subject: $subject_name (all sessions)"
        sbatch --export=SUBJECT_NAME="$subject_name" \
            $HOME/projects/def-amichaud/share/GutBrain/scripts/scripts_mriqc/18_mriqc_v3.sh
        ((submitted_count++))
    fi
    
    # Optional: small delay to avoid overwhelming the scheduler
    sleep 0.5
done

echo "======================================"
echo "Jobs submitted: $submitted_count"
echo "Jobs skipped: $skipped_count"
echo "======================================"
