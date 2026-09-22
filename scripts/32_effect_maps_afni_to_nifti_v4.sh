#!/bin/bash

# Set your contrast here
contrast="v7_literature_complex_mod_view_Lo_vs_0_psc_qc_final_covariates"
AFNI_DIR="/home/pagag24/projects/def-amichaud/share/GutBrain/BIDS_results2/3dLmer/effect_maps_${contrast}"
AFNI_FILE="${AFNI_DIR}/LME_longitudinal_${contrast}+tlrc"

# List of sub-brick labels (from your 3dinfo output, in order)
labels=(
"sess_Chi-sq"
"type_chx_Chi-sq"
"sex_Chi-sq"
"bmi_baseline_Chi-sq"
"age_baseline_Chi-sq"
"handedness_Chi-sq"
"vas_debut_Chi-sq"
"run_Chi-sq"
"sess1"
"sess1_Z"
"sess2"
"sess2_Z"
"sess3"
"sess3_Z"
"sess4"
"sess4_Z"
"sess2_vs_sess1"
"sess2_vs_sess1_Z"
"sess3_vs_sess1"
"sess3_vs_sess1_Z"
"sess4_vs_sess1"
"sess4_vs_sess1_Z"
"type_chx_2_vs_1"
"type_chx_2_vs_1_Z"
"type_chx_3_vs_1"
"type_chx_3_vs_1_Z"
"sex_female_vs_male"
"sex_female_vs_male_Z"
"bmi_baseline"
"bmi_baseline_Z"
"age_baseline"
"age_baseline_Z"
"handedness_left_vs_right"
"handedness_left_vs_right_Z"
"vas_debut"
"vas_debut_Z"
"run_2_vs_1"
"run_2_vs_1_Z"
"run_3_vs_1"
"run_3_vs_1_Z"
)

cd "$AFNI_DIR" || exit 1

for i in "${!labels[@]}"; do
    label="${labels[$i]}"
    safe_label=$(echo "$label" | tr ' ' '_' | tr -cd '[:alnum:]_')
    outname="${contrast}_${safe_label}.nii.gz"
    3dAFNItoNIFTI -float -prefix "$outname" "${AFNI_FILE}[$i]"
    echo "Exported sub-brick $i ($label) to $outname"
done

echo ""
echo "Conversion complete! Exported 40 sub-bricks to $AFNI_DIR"
