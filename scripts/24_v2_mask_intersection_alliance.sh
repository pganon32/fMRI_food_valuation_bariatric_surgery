#!/bin/bash

#SBATCH --time=1:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --job-name=vmPFC_coverage
#SBATCH --account=def-amichaud
#SBATCH --output=vmPFC_coverage_%j.out
#SBATCH --error=vmPFC_coverage_%j.err

# Script to check how many voxels of vmPFC 3mm mask are not covered by functional brain masks
# Alliance Canada SBATCH version
# Author: Generated for GutBrain project
# Date: $(date)
#
# Usage:
#   ./mask_intersection_alliance.sh [derivatives_version]
#   
# Examples:
#   ./mask_intersection_alliance.sh derivatives2    # Process derivatives2
#   ./mask_intersection_alliance.sh derivatives3    # Process derivatives3
#   ./mask_intersection_alliance.sh                 # Default: derivatives2
#
# All results are saved in BIDS_results2 regardless of which derivatives is processed

# Load required modules
module load fsl

echo "Job started at: $(date)"
echo "Running on node: $(hostname)"
echo "Job ID: $SLURM_JOB_ID"
echo ""

# Configuration: Choose which derivatives to process
# Set DERIVATIVES_VERSION to "derivatives2" or "derivatives3"
DERIVATIVES_VERSION="${1:-derivatives2}"  # Default to derivatives2 if no argument provided

# Set paths for Alliance Canada
VMPFC_MASK="${HOME}/projects/def-amichaud/share/GutBrain/BIDS_results2/ROIs/cluster_vmPFC_L_merged_3mm.nii.gz"
DERIVATIVES_DIR="${HOME}/projects/def-amichaud/share/GutBrain/${DERIVATIVES_VERSION}"
BIDS_RESULTS_DIR="${HOME}/projects/def-amichaud/share/GutBrain/BIDS_results2"

echo "Configuration:"
echo "  Processing: $DERIVATIVES_VERSION"
echo "  Input directory: $DERIVATIVES_DIR"
echo "  Results will be saved in: $BIDS_RESULTS_DIR"
echo ""

# Function to process a derivatives directory
process_derivatives() {
    local DERIVATIVES_DIR_PATH=$1
    local SUFFIX=$2
    local OUTPUT_FILE="$BIDS_RESULTS_DIR/vmPFC_coverage_report_${SUFFIX}.txt"
    local INTERMEDIATE_DIR="$BIDS_RESULTS_DIR/vmPFC_coverage_intermediate_${SUFFIX}"

    echo "========================================="
    echo "Processing $DERIVATIVES_DIR_PATH"
    echo "========================================="

    # Create directory for intermediate files
    mkdir -p "$INTERMEDIATE_DIR"

    # Create output file with header
    echo "Subject,Session,Run,Total_vmPFC_voxels,Covered_voxels,Uncovered_voxels,Coverage_percentage" > "$OUTPUT_FILE"

    # Count total brain masks - try both directory structures
    TOTAL_MASKS_DIRECT=$(ls $DERIVATIVES_DIR_PATH/sub*/ses*/func/*space*desc-brain_mask*nii* 2>/dev/null | wc -l)
    TOTAL_MASKS_FMRIPREP=$(ls $DERIVATIVES_DIR_PATH/fmriprep/sub*/ses*/func/*space*desc-brain_mask*nii* 2>/dev/null | wc -l)

    # Debug output
    echo "Debug: Checking directory structures..."
    echo "  Direct structure masks found: $TOTAL_MASKS_DIRECT"
    echo "  FMRIPrep structure masks found: $TOTAL_MASKS_FMRIPREP"
    echo "  Direct pattern: $DERIVATIVES_DIR_PATH/sub*/ses*/func/*space*desc-brain_mask*nii*"
    echo "  FMRIPrep pattern: $DERIVATIVES_DIR_PATH/fmriprep/sub*/ses*/func/*space*desc-brain_mask*nii*"

    if [ "$TOTAL_MASKS_DIRECT" -gt 0 ]; then
        TOTAL_MASKS=$TOTAL_MASKS_DIRECT
        SEARCH_PATTERN="$DERIVATIVES_DIR_PATH/sub*/ses*/func/*space*desc-brain_mask*nii*"
        echo "Found $TOTAL_MASKS brain masks to process (direct structure)"
    elif [ "$TOTAL_MASKS_FMRIPREP" -gt 0 ]; then
        TOTAL_MASKS=$TOTAL_MASKS_FMRIPREP
        SEARCH_PATTERN="$DERIVATIVES_DIR_PATH/fmriprep/sub*/ses*/func/*space*desc-brain_mask*nii*"
        echo "Found $TOTAL_MASKS brain masks to process (fmriprep structure)"
    else
        echo "No brain masks found in $DERIVATIVES_DIR_PATH (tried both direct and fmriprep subdirectory structures)"
        echo "Debug: Let's check what's actually in the directories..."
        echo "  Contents of $DERIVATIVES_DIR_PATH:"
        ls -la "$DERIVATIVES_DIR_PATH" 2>/dev/null || echo "    Directory not accessible"
        if [ -d "$DERIVATIVES_DIR_PATH/fmriprep" ]; then
            echo "  Contents of $DERIVATIVES_DIR_PATH/fmriprep:"
            ls -la "$DERIVATIVES_DIR_PATH/fmriprep" 2>/dev/null || echo "    Directory not accessible"
        fi
        return
    fi

    # Loop through all functional brain masks using the determined pattern
    CURRENT_COUNT=0
    echo "Debug: Starting to process files with pattern: $SEARCH_PATTERN"
    for brain_mask in $SEARCH_PATTERN; do
        echo "Debug: Checking file: $brain_mask"
        if [ -f "$brain_mask" ]; then
            CURRENT_COUNT=$((CURRENT_COUNT + 1))

            # Extract subject, session, and run info from filename
            basename_mask=$(basename "$brain_mask")
            subject=$(echo "$basename_mask" | cut -d'_' -f1)
            session=$(echo "$basename_mask" | cut -d'_' -f2)
            run=$(echo "$basename_mask" | cut -d'_' -f4)

            echo "Processing ($CURRENT_COUNT/$TOTAL_MASKS): $subject $session $run"
            echo "  File: $brain_mask"

            # Save resampled brain mask to intermediate directory
            resampled_file="$INTERMEDIATE_DIR/resampled_${subject}_${session}_${run}.nii.gz"
            flirt -in "$brain_mask" -ref "$VMPFC_MASK" -out "$resampled_file" -applyxfm -usesqform -interp nearestneighbour

            # Create intersection of vmPFC mask and resampled brain mask
            intersection_file="$INTERMEDIATE_DIR/intersection_${subject}_${session}_${run}.nii.gz"
            fslmaths "$VMPFC_MASK" -mul "$resampled_file" "$intersection_file"

            # Count covered voxels (intersection)
            COVERED_VOXELS=$(fslstats "$intersection_file" -V | awk '{print $1}')

            # Calculate uncovered voxels
            UNCOVERED_VOXELS=$((TOTAL_VMPFC_VOXELS - COVERED_VOXELS))

            # Calculate coverage percentage
            if [ "$TOTAL_VMPFC_VOXELS" -gt 0 ]; then
                COVERAGE_PCT=$(echo "scale=2; $COVERED_VOXELS * 100 / $TOTAL_VMPFC_VOXELS" | bc)
            else
                COVERAGE_PCT=0
            fi

            # Output results
            echo "$subject,$session,$run,$TOTAL_VMPFC_VOXELS,$COVERED_VOXELS,$UNCOVERED_VOXELS,$COVERAGE_PCT" >> "$OUTPUT_FILE"
            echo "  Covered: $COVERED_VOXELS, Uncovered: $UNCOVERED_VOXELS, Coverage: $COVERAGE_PCT%"
            echo "  Saved: $resampled_file"
            echo "  Saved: $intersection_file"
        fi
    done

    echo ""
    echo "Analysis complete for $SUFFIX! Results saved to: $OUTPUT_FILE"
    echo "Intermediate files saved to: $INTERMEDIATE_DIR/"
    echo "  - resampled_*.nii.gz: Brain masks resampled to vmPFC grid"
    echo "  - intersection_*.nii.gz: vmPFC voxels covered by each brain mask"
    echo ""
    echo "Summary statistics for $SUFFIX:"
    echo "Worst coverage (lowest percentage):"
    tail -n +2 "$OUTPUT_FILE" | sort -t',' -k7 -n | head -5

    echo ""
    echo "Best coverage (highest percentage):"
    tail -n +2 "$OUTPUT_FILE" | sort -t',' -k7 -nr | head -5
    echo ""
}

# Check if vmPFC mask exists
if [ ! -f "$VMPFC_MASK" ]; then
    echo "Error: vmPFC mask not found at $VMPFC_MASK"
    exit 1
fi

# Check if derivatives directory exists
if [ ! -d "$DERIVATIVES_DIR" ]; then
    echo "Error: Derivatives directory not found at $DERIVATIVES_DIR"
    echo "Please check that $DERIVATIVES_VERSION exists in the GutBrain folder"
    exit 1
fi

# Get total number of voxels in vmPFC mask (count non-zero voxels)
TOTAL_VMPFC_VOXELS=$(fslstats "$VMPFC_MASK" -V | awk '{print $1}')
echo "Total voxels in vmPFC mask: $TOTAL_VMPFC_VOXELS"
echo ""

# Process the selected derivatives directory
process_derivatives "$DERIVATIVES_DIR" "$DERIVATIVES_VERSION"

echo "========================================="
echo "ANALYSIS SUMMARY"
echo "========================================="
echo "Processing complete for $DERIVATIVES_VERSION!"
echo ""
echo "Output files:"
echo "  - $BIDS_RESULTS_DIR/vmPFC_coverage_report_${DERIVATIVES_VERSION}.txt"
echo ""
echo "Intermediate directories:"
echo "  - $BIDS_RESULTS_DIR/vmPFC_coverage_intermediate_${DERIVATIVES_VERSION}/"
echo ""
echo "vmPFC mask used: cluster_vmPFC_L_merged_3mm.nii.gz"
echo "Location: $VMPFC_MASK"
echo ""
echo "Usage instructions:"
echo "  To run on derivatives2: ./mask_intersection_alliance.sh derivatives2"
echo "  To run on derivatives3: ./mask_intersection_alliance.sh derivatives3"
echo "  Default (no argument): derivatives2"
echo ""
echo "Job completed at: $(date)"
echo "Total runtime: $SECONDS seconds"
