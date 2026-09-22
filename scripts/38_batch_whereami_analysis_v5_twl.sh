#!/bin/bash

# Batch script to run whereami analysis on all clustered result files
# This will process all session effects, contrasts, interactions, and covariates

# ========================================================================
# Configuration - Edit these variables for different analyses
# ========================================================================

# Define contrast variable
contrast="v7_literature_complex_mod_view_Lo_vs_0_psc"

#v7_literature_complex_mod_view_Hi_vs_0_psc_twl_24_qc_final_covar
#v7_literature_complex_mod_view_Lo_vs_0_psc_twl_24_qc_final_covar
#v7_literature_complex_mod_view_Lo_vs_0_psc_twl_24_mr_th_1_ru_qc_final
#v7_literature_complex_mod_view_Lo_vs_0_psc_qc_final_covariates
#view_Hi_vs_view_low_v7_literature_complex_psc_qc_final_covariates
#mod_hi_vs_mod_lo_v7_literature_complex_psc_qc_final_covariates


# Optional suffix for different analyses (e.g., "twl_24", "removed_hunger", "no_covariates", etc.)
# Edit this each time you want to create a different version
suffix="twl_24_qc_final_covar"  # Leave empty for default, or set to "twl_24", "removed_hunger", etc.

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

# Define all files to process - matching the actual output from 3dclusterize
FILES=(
    # Session main effects
    "sess1_clustered.nii.gz"
    "sess2_clustered.nii.gz"
    "sess3_clustered.nii.gz"
    "sess4_clustered.nii.gz"
    
    # Session contrasts
    "sess2vs1_clustered.nii.gz"
    "sess3vs1_clustered.nii.gz"
    "sess4vs1_clustered.nii.gz"
    
    # Session × TWL interactions
    "sess1_x_twl24_clustered.nii.gz"
    "sess2_x_twl24_clustered.nii.gz"
    "sess3_x_twl24_clustered.nii.gz"
    "sess4_x_twl24_clustered.nii.gz"
    
    # Session contrast × TWL interactions
    "sess2vs1_x_twl24_clustered.nii.gz"
    "sess3vs1_x_twl24_clustered.nii.gz"
    "sess4vs1_x_twl24_clustered.nii.gz"
    
    # Categorical covariates - Treatment group
    "type_chx_2vs1_clustered.nii.gz"
    "type_chx_3vs1_clustered.nii.gz"
    
    # Categorical covariates - Sex
    "sex_fvM_clustered.nii.gz"
    
    # Categorical covariates - Handedness
    "handedness_LvR_clustered.nii.gz"
    
    # Categorical covariates - Run
    "run_2vs1_clustered.nii.gz"
    "run_3vs1_clustered.nii.gz"
    
    # Continuous covariates
    "bmi_baseline_clustered.nii.gz"
    "age_baseline_clustered.nii.gz"
    "vas_debut_clustered.nii.gz"
    "twl_rech_24_clustered.nii.gz"
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
SKIPPED=0

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
        SKIPPED=$((SKIPPED + 1))
        echo "" | tee -a "$LOG_FILE"
        continue
    fi
    
    # Check if file is empty (no clusters found)
    FILE_SIZE=$(stat -c%s "$FULL_PATH" 2>/dev/null || echo "0")
    if [ "$FILE_SIZE" -lt 1000 ]; then
        echo "  INFO: File appears empty (no clusters), skipping" | tee -a "$LOG_FILE"
        SKIPPED=$((SKIPPED + 1))
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
echo "Skipped:        $SKIPPED (not found or empty)"
echo "Failed:         $FAILED"
echo "Log file:       $LOG_FILE"
echo "Results dir:    ${BASE_DIR}/atlas_coverage_reports"
echo ""
echo "Processed categories:"
echo "  - Session effects (4 main + 3 contrasts)"
echo "  - Session × TWL interactions (4 main + 3 contrasts)"
echo "  - Treatment group effects (2)"
echo "  - Demographic effects (sex, handedness)"
echo "  - Run effects (2)"
echo "  - Continuous covariates (BMI, age, hunger, TWL)"
echo "=========================================================================="

echo "" >> "$LOG_FILE"
echo "Batch WhereAmI Analysis - Completed: $(date)" >> "$LOG_FILE"
echo "Summary: $SUCCESS successful, $SKIPPED skipped, $FAILED failed out of $TOTAL total files" >> "$LOG_FILE"

exit 0
