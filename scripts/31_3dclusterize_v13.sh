#!/bin/bash

# Define contrast
CONTRAST="mod_hi_vs_mod_lo_v7_literature_complex_psc"

# Optional suffix for different analyses (e.g., "twl_24", "removed_hunger", "no_covariates", etc.)
# Edit this each time you want to create a different version
#suffix="qc_final_covariates"  # Leave empty for default, or set to "twl_24", "removed_hunger", etc.
suffix="qc_final_covar"

# Build paths with optional suffix
if [ -n "$suffix" ]; then
    OUTDIR="/home/pagag24/projects/def-amichaud/share/GutBrain/BIDS_results2/3dLmer/results/${CONTRAST}_${suffix}"
    EFFECT_MAPS_DIR="/home/pagag24/projects/def-amichaud/share/GutBrain/BIDS_results2/3dLmer/effect_maps_${CONTRAST}_${suffix}"
    LME_PREFIX="LME_longitudinal_${CONTRAST}_${suffix}"
    MASK_PREFIX="group_mask_50pct_${suffix}"
    CLUSTSIM_SUFFIX="_${suffix}"
    echo "Using custom suffix: $suffix"
else
    OUTDIR="/home/pagag24/projects/def-amichaud/share/GutBrain/BIDS_results2/3dLmer/results/${CONTRAST}"
    EFFECT_MAPS_DIR="/home/pagag24/projects/def-amichaud/share/GutBrain/BIDS_results2/3dLmer/effect_maps_${CONTRAST}"
    LME_PREFIX="LME_longitudinal_${CONTRAST}"
    MASK_PREFIX="group_mask_50pct"
    CLUSTSIM_SUFFIX=""
    echo "No suffix specified - using default output directory"
fi

mkdir -p "$OUTDIR"

echo "Contrast: $CONTRAST"
echo "Suffix: ${suffix:-none}"
echo "Output directory: $OUTDIR"
echo "Effect maps directory: $EFFECT_MAPS_DIR"
echo ""

# Prefer contrast-specific ClustSim file, fallback to top-level results if needed
CLUSTSIM_FILE="$OUTDIR/ClustSim_ACF_residuals_${CONTRAST}${CLUSTSIM_SUFFIX}.NN1_2sided.1D"
if [ ! -f "$CLUSTSIM_FILE" ]; then
    CLUSTSIM_FILE="/home/pagag24/projects/def-amichaud/share/GutBrain/BIDS_results2/3dLmer/results/ClustSim_ACF_residuals_${CONTRAST}${CLUSTSIM_SUFFIX}.NN1_2sided.1D"
fi

if [ ! -f "$CLUSTSIM_FILE" ]; then
    echo "Error: ClustSim results file not found (checked ${CONTRAST}${CLUSTSIM_SUFFIX} and top-level results)."
    echo "Expected: $OUTDIR/ClustSim_ACF_residuals_${CONTRAST}${CLUSTSIM_SUFFIX}.NN1_2sided.1D"
    echo "      or: /home/pagag24/projects/def-amichaud/share/GutBrain/BIDS_results2/3dLmer/results/ClustSim_ACF_residuals_${CONTRAST}${CLUSTSIM_SUFFIX}.NN1_2sided.1D"
    exit 1
fi

echo "Reading cluster threshold for p=0.001 (alpha=0.05) from: $CLUSTSIM_FILE"
CLUST_SIZE_001=$(awk '/^ 0\.001000/ {print int($2 + 0.5)}' "$CLUSTSIM_FILE")
if [ -z "$CLUST_SIZE_001" ]; then
    echo "Warning: Could not find cluster size for p=0.001, alpha=0.05. Using default 84."
    CLUST_SIZE_001=84
else
    echo "Found cluster size for p=0.001, alpha=0.05: $CLUST_SIZE_001 voxels (residuals-based ACF, ${CONTRAST}${CLUSTSIM_SUFFIX})"
fi

# Build output filename suffix
OUT_SUFFIX="${CONTRAST}${CLUSTSIM_SUFFIX}"

# Remove old clustered output files to avoid overwrite issues
for PREF in "sess1" "sess2" "sess3" "sess4" "sess2vs1" "sess3vs1" "sess4vs1" \
    "sess_chisq" "type_chx_chisq" "sex_chisq" "bmi_baseline_chisq" \
    "age_baseline_chisq" "handedness_chisq" "vas_debut_chisq" "run_chisq"; do
    for EXT in "+tlrc.HEAD" "+tlrc.BRIK" ".nii.gz" \
        "_clusters_p001_ACF_residuals_${OUT_SUFFIX}.txt" \
        "_clusters_p001_ACF_residuals_${OUT_SUFFIX}.txt+tlrc.HEAD" \
        "_clusters_p001_ACF_residuals_${OUT_SUFFIX}.txt+tlrc.BRIK" \
        "_clustered_p001_ACF_residuals_${OUT_SUFFIX}+tlrc.HEAD" \
        "_clusters_p001_ACF_residuals_${OUT_SUFFIX}.1D" \
        "_clustered_p001_ACF_residuals_${OUT_SUFFIX}+tlrc.BRIK"; do
        FILE="$OUTDIR/${PREF}${EXT}"
        if [ -f "$FILE" ]; then
            echo "Removing old file: $FILE"
            rm -f "$FILE"
        fi
    done
done

IN_PREFIX="${EFFECT_MAPS_DIR}/${LME_PREFIX}+tlrc.BRIK"
MASK="${EFFECT_MAPS_DIR}/${MASK_PREFIX}+tlrc"

# Check if input files exist
if [ ! -f "$IN_PREFIX" ]; then
    echo "Error: Input file not found: $IN_PREFIX"
    exit 1
fi

if [ ! -f "${MASK}.HEAD" ]; then
    echo "Error: Mask file not found: ${MASK}.HEAD"
    exit 1
fi

# Chi-square threshold for p=0.001 with df=2: 13.816
CHISQ_THRESH=13.816

echo ""
echo "=========================================="
echo "Processing Chi-square maps (p=0.001, Chi-sq > ${CHISQ_THRESH}, df=2)..."
echo "=========================================="

# Sub-brick indices for Chi-square maps and corresponding prefixes
declare -a CHISQ_SUBBRICKS=("0" "1" "2" "3" "4" "5" "6" "7")
declare -a CHISQ_PREFIXES=("sess_chisq" "type_chx_chisq" "sex_chisq" "bmi_baseline_chisq" \
    "age_baseline_chisq" "handedness_chisq" "vas_debut_chisq" "run_chisq")
declare -a CHISQ_LABELS=("sess" "type_chx" "sex" "bmi_baseline" \
    "age_baseline" "handedness" "vas_debut" "run")

for i in "${!CHISQ_SUBBRICKS[@]}"; do
    SB=${CHISQ_SUBBRICKS[$i]}
    PREF=${CHISQ_PREFIXES[$i]}
    LABEL=${CHISQ_LABELS[$i]}
    echo "Clustering $LABEL Chi-sq (sub-brick $SB)..."
    3dClusterize -nosum \
        -1Dformat \
        -inset "${IN_PREFIX}[$SB]" \
        -idat 0 \
        -ithr 0 \
        -NN 1 \
        -clust_nvox $CLUST_SIZE_001 \
        -pref_map "$OUTDIR/${PREF}_clustered_p001_ACF_residuals_${OUT_SUFFIX}" \
        -pref_dat "$OUTDIR/${PREF}_clusters_p001_ACF_residuals_${OUT_SUFFIX}.1D" \
        -1sided RIGHT_TAIL ${CHISQ_THRESH} \
        -mask "$MASK"

    # Convert to NIFTI_GZ
    if [ -f "$OUTDIR/${PREF}_clustered_p001_ACF_residuals_${OUT_SUFFIX}+tlrc.BRIK" ]; then
        3dAFNItoNIFTI -prefix "$OUTDIR/${PREF}_clustered_p001_ACF_residuals_${OUT_SUFFIX}.nii.gz" \
            "$OUTDIR/${PREF}_clustered_p001_ACF_residuals_${OUT_SUFFIX}+tlrc.BRIK"
    fi


    # Run whereami for Glasser atlas only
    if [ -s "$OUTDIR/${PREF}_clusters_p001_ACF_residuals_${OUT_SUFFIX}.1D" ]; then
        echo "Atlas info for $LABEL Chi-sq clusters (Glasser only):"
        whereami -atlas MNI_Glasser_HCP_v1.0 -coord_file "$OUTDIR/${PREF}_clusters_p001_ACF_residuals_${OUT_SUFFIX}.1D[0,1,2]" -tab
    else
        echo "No clusters found for $LABEL Chi-sq."
    fi
done

echo ""
echo "=========================================="
echo "Processing Z-score maps (p=0.001, Z=±3.29)..."
echo "=========================================="


# Sub-brick indices for Z-score maps and corresponding prefixes
# Updated to match new output structure where Z-scores are at odd indices
declare -a SUBBRICKS=("9" "11" "13" "15" "17" "19" "21" "23" "25" "27" "29" "31" "33" "35" "37" "39")
declare -a PREFIXES=("sess1" "sess2" "sess3" "sess4" "sess2vs1" "sess3vs1" "sess4vs1" \
    "type_chx_2vs1" "type_chx_3vs1" "sex_fvs_m" "bmi_baseline" "age_baseline" \
    "handedness_lvs_r" "vas_debut" "run_2vs1" "run_3vs1")

for i in "${!SUBBRICKS[@]}"; do
    SB=${SUBBRICKS[$i]}
    PREF=${PREFIXES[$i]}
    echo "Clustering $PREF (sub-brick $SB)..."
    3dClusterize -nosum \
        -1Dformat \
        -inset "${IN_PREFIX}[$SB]" \
        -idat 0 \
        -ithr 0 \
        -NN 1 \
        -clust_nvox $CLUST_SIZE_001 \
        -pref_map "$OUTDIR/${PREF}_clustered_p001_ACF_residuals_${OUT_SUFFIX}" \
        -pref_dat "$OUTDIR/${PREF}_clusters_p001_ACF_residuals_${OUT_SUFFIX}.1D" \
        -bisided -3.29 3.29 \
        -mask "$MASK"


    # Convert to NIFTI_GZ
    if [ -f "$OUTDIR/${PREF}_clustered_p001_ACF_residuals_${OUT_SUFFIX}+tlrc.BRIK" ]; then
        3dAFNItoNIFTI -prefix "$OUTDIR/${PREF}_clustered_p001_ACF_residuals_${OUT_SUFFIX}.nii.gz" \
            "$OUTDIR/${PREF}_clustered_p001_ACF_residuals_${OUT_SUFFIX}+tlrc.BRIK"
    fi



    # Run whereami for Glasser atlas only
    if [ -s "$OUTDIR/${PREF}_clusters_p001_ACF_residuals_${OUT_SUFFIX}.1D" ]; then
        echo "Atlas info for $PREF clusters (Glasser only):"
        whereami -atlas MNI_Glasser_HCP_v1.0 -coord_file "$OUTDIR/${PREF}_clusters_p001_ACF_residuals_${OUT_SUFFIX}.1D[0,1,2]" -tab
    else
        echo "No clusters found for $PREF."
    fi

done

echo ""
echo "=========================================="
echo "Clustering complete! Results stored in: $OUTDIR"
echo ""
echo "Chi-square maps (p=0.001, ${CLUST_SIZE_001} voxels):"
for PREF in "${CHISQ_PREFIXES[@]}"; do
    echo "  ${PREF}_clustered_p001_ACF_residuals_${OUT_SUFFIX}.nii.gz"
done
echo ""
echo "Z-score maps (p=0.001, ${CLUST_SIZE_001} voxels):"
for PREF in "${PREFIXES[@]}"; do
    echo "  ${PREF}_clustered_p001_ACF_residuals_${OUT_SUFFIX}.nii.gz"
done
echo "=========================================="
