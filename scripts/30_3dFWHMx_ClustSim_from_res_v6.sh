#!/bin/bash

# =============================================================================
# Configuration Section - Modify these variables as needed
# =============================================================================

# Base directories
RESULTS_DIR="/home/pagag24/projects/def-amichaud/share/GutBrain/BIDS_results2/3dLmer"
BIDS_RESULTS_DIR="/home/pagag24/projects/def-amichaud/share/GutBrain/BIDS_results2"

# Contrast/analysis name
#CONTRAST="v7_literature_complex_mod_view_Lo_vs_0_psc"
CONTRAST="mod_hi_vs_mod_lo_v7_literature_complex_psc"


# Optional suffix for different analyses (e.g., "twl_24", "removed_hunger", "no_covariates", etc.)
# Edit this each time you want to match a different version
# This should match the suffix used in working_3dLMEr script
#SUFFIX="twl_24_qc_final_covar"  # Leave empty for default, or set to "twl_24", "removed_hunger", etc.
SUFFIX="qc_final_covar"

# Build paths with optional suffix
if [ -n "$SUFFIX" ]; then
    EFFECT_MAPS_DIR="${RESULTS_DIR}/effect_maps_${CONTRAST}_${SUFFIX}"
    OUTPUT_DIR="${RESULTS_DIR}/results/${CONTRAST}_${SUFFIX}"
    MASK_FILE="${EFFECT_MAPS_DIR}/group_mask_50pct_${SUFFIX}+tlrc"
    DATA_TABLE="${EFFECT_MAPS_DIR}/LME_longitudinal_datatable_${CONTRAST}_${SUFFIX}.txt"
    OUTPUT_PREFIX="${CONTRAST}_${SUFFIX}"
    echo "Using custom suffix: $SUFFIX"
else
    EFFECT_MAPS_DIR="${RESULTS_DIR}/effect_maps_${CONTRAST}"
    OUTPUT_DIR="${RESULTS_DIR}/results/${CONTRAST}"
    MASK_FILE="${EFFECT_MAPS_DIR}/group_mask_50pct+tlrc"
    DATA_TABLE="${EFFECT_MAPS_DIR}/LME_longitudinal_datatable_${CONTRAST}.txt"
    OUTPUT_PREFIX="${CONTRAST}"
    echo "No suffix specified - using default paths"
fi

# ClustSim parameters
ITER=10000
ALPHA_THRESHOLDS="0.05 0.02 0.01"
P_THRESHOLDS="0.001 0.002 0.005 0.01"

# =============================================================================
# Main Script - No need to modify below this line
# =============================================================================

echo "=============================================="
echo "Configuration:"
echo "  Contrast: ${CONTRAST}"
echo "  Suffix: ${SUFFIX:-<none>}"
echo "  Effect maps dir: ${EFFECT_MAPS_DIR}"
echo "  Output dir: ${OUTPUT_DIR}"
echo "  Mask file: ${MASK_FILE}"
echo "  Data table: ${DATA_TABLE}"
echo "  Output prefix: ${OUTPUT_PREFIX}"
echo "=============================================="

# Create the output directory if it doesn't exist
mkdir -p "${OUTPUT_DIR}"

# Check if required files exist
if [ ! -f "${DATA_TABLE}" ]; then
    echo "ERROR: Data table not found: ${DATA_TABLE}"
    exit 1
fi

if [ ! -f "${MASK_FILE}.HEAD" ] && [ ! -f "${MASK_FILE}" ]; then
    echo "ERROR: Mask file not found: ${MASK_FILE}"
    exit 1
fi

# Step 1: Estimate ACF parameters from individual residual maps
echo ""
echo "=============================================="
echo "Estimating ACF parameters from individual residual maps"
echo "=============================================="

# Extract subject/session/run combinations from data table
echo "Extracting subject/session/run information from data table..."
TEMP_RESIDUAL_LIST="${OUTPUT_DIR}/temp_residual_list.txt"
> "${TEMP_RESIDUAL_LIST}"  # Clear/create empty file

# Count total entries in data table (excluding header)
TOTAL_ENTRIES=$(tail -n +2 "${DATA_TABLE}" | wc -l)
echo "Total entries in data table: ${TOTAL_ENTRIES}"

# Parse the data table (skip header, extract InputFile column - last column)
# Use process substitution to avoid subshell issue
while read input_file; do
    # Replace "effect-size" with "residuals" in the filename
    residual_file="${input_file//_effect-size_/_residuals_}"
    
    # Check if file exists and add to list
    if [ -f "${residual_file}" ]; then
        echo "${residual_file}" >> "${TEMP_RESIDUAL_LIST}"
    else
        echo "WARNING: Residual file not found: ${residual_file}"
    fi
done < <(tail -n +2 "${DATA_TABLE}" | awk '{print $NF}')

# Count number of residual files
NUM_RESIDUALS=$(wc -l < "${TEMP_RESIDUAL_LIST}")
echo "Found ${NUM_RESIDUALS} residual files matching data table entries"

if [ ${NUM_RESIDUALS} -eq 0 ]; then
    echo "ERROR: No residual files found matching data table entries"
    rm "${TEMP_RESIDUAL_LIST}"
    exit 1
fi

if [ ${NUM_RESIDUALS} -ne ${TOTAL_ENTRIES} ]; then
    echo "WARNING: Found ${NUM_RESIDUALS} residual files but expected ${TOTAL_ENTRIES}"
    echo "Some residual files may be missing!"
fi

# Show a few example files being used
echo "Example residual files:"
head -5 "${TEMP_RESIDUAL_LIST}"
echo "..."

# Run 3dFWHMx with the matched residual files
3dFWHMx -mask "${MASK_FILE}" \
        -acf \
        -input $(cat "${TEMP_RESIDUAL_LIST}") \
        > "${OUTPUT_DIR}/ACF_estimates_residuals_${OUTPUT_PREFIX}.txt"

# Clean up temporary file
rm "${TEMP_RESIDUAL_LIST}"

# Extract ACF parameters from the output (second line, columns 1-3)
ACF_PARAMS=$(awk 'NR==2 {print $1, $2, $3}' "${OUTPUT_DIR}/ACF_estimates_residuals_${OUTPUT_PREFIX}.txt")
echo "ACF parameters from residuals: $ACF_PARAMS"

# Step 2: Run 3dClustSim with the estimated ACF parameters
echo ""
echo "=============================================="
echo "Running 3dClustSim with ACF correction"
echo "=============================================="

3dClustSim -mask "${MASK_FILE}" \
           -acf $ACF_PARAMS \
           -iter ${ITER} \
           -athr ${ALPHA_THRESHOLDS} \
           -pthr ${P_THRESHOLDS} \
           -prefix "${OUTPUT_DIR}/ClustSim_ACF_residuals_${OUTPUT_PREFIX}"

echo ""
echo "=============================================="
echo "Analysis Complete!"
echo "=============================================="
echo "Contrast: ${CONTRAST}"
echo "Suffix: ${SUFFIX:-<none>}"
echo "Number of residual maps used: ${NUM_RESIDUALS}"
echo "Results saved to:"
echo "  - ${OUTPUT_DIR}/ACF_estimates_residuals_${OUTPUT_PREFIX}.txt"
echo "  - ${OUTPUT_DIR}/ClustSim_ACF_residuals_${OUTPUT_PREFIX}.NN1_2sided.1D"
echo "=============================================="
