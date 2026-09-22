#!/bin/bash

# Batch script to run whereami analysis on all clustered result files
# This will process all session effects, contrasts, interactions, and covariates

# ========================================================================
# Configuration - Edit these variables for different analyses
# ========================================================================

# Define contrast variable
contrast="v7_literature_complex_mod_view_Lo_vs_0_psc"

# Optional suffix for different analyses (e.g., "twl_24", "removed_hunger", "no_covariates", etc.)
# Edit this each time you want to create a different version
suffix="qc_final_covariates"  # Leave empty for default, or set to "twl_24", "removed_hunger", etc.

# Construct the full suffix string
if [ -n "$suffix" ]; then
    full_suffix="_${suffix}"
else
    full_suffix=""
fi

# Base directory - update this to match your results directory structure
BASE_DIR="/home/pagag24/projects/def-amichaud/share/GutBrain/BIDS_results2/3dLmer/results/${contrast}${full_suffix}"

# Atlas to use
ATLAS="Brainnetome_1.0"

# Path to whereami script
WHEREAMI_SCRIPT="/home/pagag24/projects/def-amichaud/share/GutBrain/scripts/scripts_afni/group_scripts/run_whereami_analysis.sh"

# ========================================================================
# End of Configuration
# ========================================================================

# Log file
LOG_FILE="${BASE_DIR}/batch_whereami_log_$(date +%Y%m%d_%H%M%S).txt"

echo "=========================================================================="
echo "Batch WhereAmI Analysis"
echo "=========================================================================="
echo "Contrast:       $contrast"
echo "Suffix:         ${suffix:-none}"
echo "Base directory: $BASE_DIR"
echo "Atlas:          $ATLAS"
echo "Script:         $WHEREAMI_SCRIPT"
echo "Log file:       $LOG_FILE"
echo "=========================================================================="
echo ""

# Check if whereami script exists
if [ ! -f "$WHEREAMI_SCRIPT" ]; then
    echo "ERROR: WhereAmI script not found at $WHEREAMI_SCRIPT"
    echo "Please update WHEREAMI_SCRIPT variable with correct path"
    exit 1
fi

# Check if base directory exists
if [ ! -d "$BASE_DIR" ]; then
    echo "ERROR: Base directory not found: $BASE_DIR"
    exit 1
fi

# Define all files to process using the contrast and suffix variables
FILES=(
    # Chi-square covariate maps (processed first)
    "sess_chisq_clustered_p001_ACF_residuals_${contrast}${full_suffix}.nii.gz"
    "type_chx_chisq_clustered_p001_ACF_residuals_${contrast}${full_suffix}.nii.gz"
    "sex_chisq_clustered_p001_ACF_residuals_${contrast}${full_suffix}.nii.gz"
    "bmi_baseline_chisq_clustered_p001_ACF_residuals_${contrast}${full_suffix}.nii.gz"
    "age_baseline_chisq_clustered_p001_ACF_residuals_${contrast}${full_suffix}.nii.gz"
    "handedness_chisq_clustered_p001_ACF_residuals_${contrast}${full_suffix}.nii.gz"
    "vas_debut_chisq_clustered_p001_ACF_residuals_${contrast}${full_suffix}.nii.gz"
    "run_chisq_clustered_p001_ACF_residuals_${contrast}${full_suffix}.nii.gz"

    # Session main effects (Z-score maps)
    "sess1_clustered_p001_ACF_residuals_${contrast}${full_suffix}.nii.gz"
    "sess2_clustered_p001_ACF_residuals_${contrast}${full_suffix}.nii.gz"
    "sess3_clustered_p001_ACF_residuals_${contrast}${full_suffix}.nii.gz"
    "sess4_clustered_p001_ACF_residuals_${contrast}${full_suffix}.nii.gz"

    # Session contrasts (Z-score maps)
    "sess2vs1_clustered_p001_ACF_residuals_${contrast}${full_suffix}.nii.gz"
    "sess3vs1_clustered_p001_ACF_residuals_${contrast}${full_suffix}.nii.gz"
    "sess4vs1_clustered_p001_ACF_residuals_${contrast}${full_suffix}.nii.gz"

    # Type surgery contrasts (Z-score maps)
    "type_chx_2vs1_clustered_p001_ACF_residuals_${contrast}${full_suffix}.nii.gz"
    "type_chx_3vs1_clustered_p001_ACF_residuals_${contrast}${full_suffix}.nii.gz"

    # Sex contrast (Z-score map)
    "sex_fvs_m_clustered_p001_ACF_residuals_${contrast}${full_suffix}.nii.gz"

    # Continuous covariates (Z-score maps)
    "bmi_baseline_clustered_p001_ACF_residuals_${contrast}${full_suffix}.nii.gz"
    "age_baseline_clustered_p001_ACF_residuals_${contrast}${full_suffix}.nii.gz"
    "vas_debut_clustered_p001_ACF_residuals_${contrast}${full_suffix}.nii.gz"

    # Handedness contrast (Z-score map)
    "handedness_lvs_r_clustered_p001_ACF_residuals_${contrast}${full_suffix}.nii.gz"

    # Run contrasts (Z-score maps)
    "run_2vs1_clustered_p001_ACF_residuals_${contrast}${full_suffix}.nii.gz"
    "run_3vs1_clustered_p001_ACF_residuals_${contrast}${full_suffix}.nii.gz"
)

# Initialize log
echo "Batch WhereAmI Analysis - Started: $(date)" | tee "$LOG_FILE"
echo "Contrast: $contrast" | tee -a "$LOG_FILE"
echo "Suffix: ${suffix:-none}" | tee -a "$LOG_FILE"
echo "Total files to process: ${#FILES[@]}" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Counter for progress tracking
TOTAL=${#FILES[@]}
CURRENT=0
SUCCESS=0
FAILED=0

# Process each file
for FILE in "${FILES[@]}"; do
    CURRENT=$((CURRENT + 1))
    FULL_PATH="${BASE_DIR}/${FILE}"

    echo "=========================================================================="
    echo "[$CURRENT/$TOTAL] Processing: $FILE"
    echo "=========================================================================="
    echo "[$CURRENT/$TOTAL] Processing: $FILE" >> "$LOG_FILE"

    # Check if file exists
    if [ ! -f "$FULL_PATH" ]; then
        echo "  WARNING: File not found, skipping: $FULL_PATH" | tee -a "$LOG_FILE"
        FAILED=$((FAILED + 1))
        echo "" | tee -a "$LOG_FILE"
        continue
    fi

    # Run whereami analysis
    echo "  Running whereami analysis..." | tee -a "$LOG_FILE"
    bash "$WHEREAMI_SCRIPT" "$FULL_PATH" "$ATLAS" >> "$LOG_FILE" 2>&1

    if [ $? -eq 0 ]; then
        echo "  ✓ SUCCESS" | tee -a "$LOG_FILE"
        SUCCESS=$((SUCCESS + 1))
    else
        echo "  ✗ FAILED" | tee -a "$LOG_FILE"
        FAILED=$((FAILED + 1))
    fi

    echo "" | tee -a "$LOG_FILE"
done

# Summary
echo "=========================================================================="
echo "Batch Processing Complete!"
echo "=========================================================================="
echo "Contrast:       $contrast"
echo "Suffix:         ${suffix:-none}"
echo "Total files:    $TOTAL"
echo "Successful:     $SUCCESS"
echo "Failed:         $FAILED"
echo "Log file:       $LOG_FILE"
echo "Results dir:    ${BASE_DIR}/atlas_coverage_reports"
echo "=========================================================================="

echo "" >> "$LOG_FILE"
echo "Batch WhereAmI Analysis - Completed: $(date)" >> "$LOG_FILE"
echo "Summary: $SUCCESS successful, $FAILED failed out of $TOTAL total files" >> "$LOG_FILE"

exit 0
