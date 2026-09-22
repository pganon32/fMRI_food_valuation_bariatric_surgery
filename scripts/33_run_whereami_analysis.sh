#!/bin/bash

# Script to refit contrast maps to MNI space and run whereami atlas overlap analysis
# Usage: ./run_whereami_analysis.sh <absolute_path_to_input_map.nii.gz> [atlas_name]

# Check if input file is provided
if [ $# -lt 1 ]; then
    echo "Usage: $0 <absolute_path_to_input_map.nii.gz> [atlas_name]"
    echo ""
    echo "Arguments:"
    echo "  absolute_path_to_input_map.nii.gz : Full path to the contrast/cluster map (required)"
    echo "  atlas_name                        : Atlas to use (default: MNI_Glasser_HCP_v1.0)"
    echo "                                      Options: MNI_Glasser_HCP_v1.0, Brodmann_Pijn_AFNI, CA_N27_MPM"
    echo ""
    echo "Example:"
    echo "  $0 /home/pagag24/projects/def-amichaud/share/GutBrain/BIDS_results2/group/ses-2/results/sess2_clustered_p001_ACF_residuals.nii.gz"
    echo "  $0 /full/path/to/map.nii.gz Brodmann_Pijn_AFNI"
    exit 1
fi

# Input arguments
INPUT_MAP="$1"
ATLAS="${2:-MNI_Glasser_HCP_v1.0}"

# Check if input is an absolute path
if [[ "$INPUT_MAP" != /* ]]; then
    echo "ERROR: Please provide an absolute path (starting with /)"
    echo "You provided: $INPUT_MAP"
    exit 1
fi

# Check if input file exists
if [ ! -f "$INPUT_MAP" ]; then
    echo "ERROR: Input file not found: $INPUT_MAP"
    exit 1
fi

# Get directory and basename
INPUT_DIR=$(dirname "$INPUT_MAP")
BASENAME=$(basename "$INPUT_MAP" .nii.gz)

# Create atlas_coverage_reports directory
REPORTS_DIR="${INPUT_DIR}/atlas_coverage_reports"
mkdir -p "$REPORTS_DIR"

# Output files go in the atlas_coverage_reports folder
MNI_MAP="${REPORTS_DIR}/${BASENAME}_MNI.nii.gz"
WHEREAMI_REPORT="${REPORTS_DIR}/${BASENAME}_${ATLAS}_whereami_report.txt"

echo "=========================================================================="
echo "WhereAmI Atlas Overlap Analysis"
echo "=========================================================================="
echo "Input map:        $INPUT_MAP"
echo "Atlas:            $ATLAS"
echo "Output directory: $REPORTS_DIR"
echo "=========================================================================="

# Check current space
echo ""
echo "Step 1: Checking current space..."
CURRENT_SPACE=$(3dinfo -space "$INPUT_MAP")
echo "Current space: $CURRENT_SPACE"

# Copy and refit to MNI space
echo ""
echo "Step 2: Creating MNI version..."
if [ -f "$MNI_MAP" ]; then
    echo "WARNING: $MNI_MAP already exists. Overwriting..."
    rm "$MNI_MAP"
fi

3dcopy "$INPUT_MAP" "$MNI_MAP"
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to copy file"
    exit 1
fi

echo "Refitting to MNI space..."
3drefit -space MNI -view tlrc "$MNI_MAP"
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to refit to MNI space"
    exit 1
fi

# Verify the fix
NEW_SPACE=$(3dinfo -space "$MNI_MAP")
echo "New space: $NEW_SPACE"

# Get map information
echo ""
echo "Step 3: Map information..."
echo "Resolution: $(3dinfo -d3 $MNI_MAP)"
echo "Orientation: $(3dinfo -orient $MNI_MAP)"

# Run whereami
echo ""
echo "Step 4: Running whereami analysis with $ATLAS atlas..."
whereami -omask "$MNI_MAP" \
         -atlas "$ATLAS" \
         -lpi \
         -max_areas 10 \
         -show_atlas_code \
         -tab \
         > "$WHEREAMI_REPORT"

if [ $? -ne 0 ]; then
    echo "ERROR: whereami failed"
    exit 1
fi

# Display results
echo ""
echo "=========================================================================="
echo "Analysis Complete!"
echo "=========================================================================="
echo "MNI map saved to:     $MNI_MAP"
echo "WhereAmI report:      $WHEREAMI_REPORT"
echo "=========================================================================="
echo ""
echo "Results preview:"
echo "--------------------------------------------------------------------------"
head -50 "$WHEREAMI_REPORT"
echo "--------------------------------------------------------------------------"
echo ""
echo "Full report: $WHEREAMI_REPORT"
echo ""
echo "Done!"
