#!/bin/bash

# Set your contrast here
contrast="view_Hi_vs_view_low_v7_literature_complex_psc"

# Optional suffix for different analyses (e.g., "twl_24", "removed_hunger", "no_covariates", etc.)
# Edit this each time you want to create a different version
suffix="twl_24_qc_final_covar"  # Leave empty for default, or set to "twl_24", "removed_hunger", etc.

# Build paths with optional suffix
if [ -n "$suffix" ]; then
    AFNI_DIR="/home/pagag24/projects/def-amichaud/share/GutBrain/BIDS_results2/3dLmer/effect_maps_${contrast}_${suffix}"
    AFNI_FILE="${AFNI_DIR}/LME_longitudinal_${contrast}_${suffix}+tlrc"
    echo "Using custom suffix: $suffix"
else
    AFNI_DIR="/home/pagag24/projects/def-amichaud/share/GutBrain/BIDS_results2/3dLmer/effect_maps_${contrast}"
    AFNI_FILE="${AFNI_DIR}/LME_longitudinal_${contrast}+tlrc"
    echo "No suffix specified - using default paths"
fi

echo "Contrast: $contrast"
echo "Suffix: ${suffix:-none}"
echo "AFNI directory: $AFNI_DIR"
echo "AFNI file: $AFNI_FILE"
echo ""

# List of sub-brick labels (from your 3dinfo output with sess*twl_rech_24 interaction model + all covariates)
labels=(
"sess_Chi-sq"                      # 0
"twl_rech_24_Chi-sq"              # 1
"type_chx_Chi-sq"                 # 2
"sex_Chi-sq"                      # 3
"bmi_baseline_Chi-sq"             # 4
"age_baseline_Chi-sq"             # 5
"handedness_Chi-sq"               # 6
"vas_debut_Chi-sq"                # 7
"run_Chi-sq"                      # 8
"sess_twl_rech_24_Chi-sq"         # 9
"sess1"                           # 10
"sess1_Z"                         # 11
"sess2"                           # 12
"sess2_Z"                         # 13
"sess3"                           # 14
"sess3_Z"                         # 15
"sess4"                           # 16
"sess4_Z"                         # 17
"sess2_vs_sess1"                  # 18
"sess2_vs_sess1_Z"                # 19
"sess3_vs_sess1"                  # 20
"sess3_vs_sess1_Z"                # 21
"sess4_vs_sess1"                  # 22
"sess4_vs_sess1_Z"                # 23
"sess1_x_twl24"                   # 24
"sess1_x_twl24_Z"                 # 25
"sess2_x_twl24"                   # 26
"sess2_x_twl24_Z"                 # 27
"sess3_x_twl24"                   # 28
"sess3_x_twl24_Z"                 # 29
"sess4_x_twl24"                   # 30
"sess4_x_twl24_Z"                 # 31
"sess2_vs_sess1_x_twl24"          # 32
"sess2_vs_sess1_x_twl24_Z"        # 33
"sess3_vs_sess1_x_twl24"          # 34
"sess3_vs_sess1_x_twl24_Z"        # 35
"sess4_vs_sess1_x_twl24"          # 36
"sess4_vs_sess1_x_twl24_Z"        # 37
"type_chx_2_vs_1"                 # 38
"type_chx_2_vs_1_Z"               # 39
"type_chx_3_vs_1"                 # 40
"type_chx_3_vs_1_Z"               # 41
"sex_female_vs_male"              # 42
"sex_female_vs_male_Z"            # 43
"bmi_baseline"                    # 44
"bmi_baseline_Z"                  # 45
"age_baseline"                    # 46
"age_baseline_Z"                  # 47
"handedness_left_vs_right"        # 48
"handedness_left_vs_right_Z"      # 49
"vas_debut"                       # 50
"vas_debut_Z"                     # 51
"twl_rech_24"                     # 52
"twl_rech_24_Z"                   # 53
"run_2_vs_1"                      # 54
"run_2_vs_1_Z"                    # 55
"run_3_vs_1"                      # 56
"run_3_vs_1_Z"                    # 57
)

# Check if AFNI file exists
if [ ! -f "${AFNI_FILE}.HEAD" ]; then
    echo "Error: AFNI file not found: ${AFNI_FILE}.HEAD"
    exit 1
fi

cd "$AFNI_DIR" || exit 1

echo "Exporting ${#labels[@]} sub-bricks to NIfTI format..."
echo ""

for i in "${!labels[@]}"; do
    label="${labels[$i]}"
    safe_label=$(echo "$label" | tr ' ' '_' | tr -cd '[:alnum:]_')
    
    if [ -n "$suffix" ]; then
        outname="${contrast}_${suffix}_${safe_label}.nii.gz"
    else
        outname="${contrast}_${safe_label}.nii.gz"
    fi
    rm -f "$outname"
    3dAFNItoNIFTI -float -prefix "$outname" "${AFNI_FILE}[$i]"
    echo "Exported sub-brick $i ($label) to $outname"
done

echo ""
echo "=============================================="
echo "Export complete!"
echo "Total sub-bricks exported: ${#labels[@]}"
echo ""
echo "Session effects (main + contrasts):"
echo "  - sess1-4 (coefficient + Z)"
echo "  - sess2_vs_sess1, sess3_vs_sess1, sess4_vs_sess1 (coefficient + Z)"
echo ""
echo "Session × TWL interactions:"
echo "  - sess1-4_x_twl24 (coefficient + Z)"
echo "  - sess2_vs_sess1_x_twl24, sess3_vs_sess1_x_twl24, sess4_vs_sess1_x_twl24 (coefficient + Z)"
echo ""
echo "Categorical covariates:"
echo "  - type_chx_2_vs_1, type_chx_3_vs_1 (coefficient + Z)"
echo "  - sex_female_vs_male (coefficient + Z)"
echo "  - handedness_left_vs_right (coefficient + Z)"
echo "  - run_2_vs_1, run_3_vs_1 (coefficient + Z)"
echo ""
echo "Continuous covariates:"
echo "  - bmi_baseline (coefficient + Z)"
echo "  - age_baseline (coefficient + Z)"
echo "  - vas_debut (coefficient + Z)"
echo "  - twl_rech_24 (coefficient + Z)"
echo ""
echo "Output directory: $AFNI_DIR"
echo "=============================================="
