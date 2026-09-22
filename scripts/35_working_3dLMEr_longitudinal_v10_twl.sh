#!/bin/sh
#SBATCH --job-name=3dLMEr_longitudinal
#SBATCH --time=1:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=100G
#SBATCH --output=3dLMEr_longitudinal_%j.out
#SBATCH --error=3dLMEr_longitudinal_%j.err

module use /cvmfs/neurodesk.ardc.edu.au/neurodesk-modules/* 
module load apptainer
module load afni/23.3.02

echo "🧠 WORKING 3dLMEr Analysis - Longitudinal Food Auction Task 🧠"
echo "Job ID: $SLURM_JOB_ID"
echo "Running on: $SLURM_JOBODELIST"
echo "CPUs allocated: $SLURM_CPUS_PER_TASK"
echo "Memory allocated: 100GB"
echo "Time limit: 4 hours"
echo ""

#v7_literature_complex_mod_view_Hi_vs_0_psc_twl_24_qc_final_covar
#v7_literature_complex_mod_view_Lo_vs_0_psc_twl_24_qc_final_covar
#v7_literature_complex_mod_view_Lo_vs_0_psc_twl_24_mr_th_1_ru_qc_final
#v7_literature_complex_mod_view_Lo_vs_0_psc_qc_final_covariates
#view_Hi_vs_view_low_v7_literature_complex_psc_qc_final_covariates
#mod_hi_vs_mod_lo_v7_literature_complex_psc_qc_final_covariates


# Define contrast variable
contrast="v7_literature_complex_mod_view_Lo_vs_0_psc"

# Optional suffix for different analyses (e.g., "twl_24", "removed_hunger", "no_covariates", etc.)
# Edit this each time you want to create a different version
suffix="twl_24_qc_final_covar"  # Leave empty for default, or set to "twl_24", "removed_hunger", etc.

# Build data table filename with optional suffix
if [ -n "$suffix" ]; then
    data_table_file="3dlmerdata_table_with_covariates_${contrast}_${suffix}.txt"
    out_dir="/home/pagag24/projects/def-amichaud/share/GutBrain/BIDS_results2/3dLmer/effect_maps_${contrast}_${suffix}"
    output_prefix="LME_longitudinal_${contrast}_${suffix}"
    datatable_name="LME_longitudinal_datatable_${contrast}_${suffix}.txt"
    AFNI_MASK="group_mask_50pct_${suffix}"
    echo "Using custom suffix: $suffix"
else
    data_table_file="3dlmerdata_table_with_covariates_${contrast}.txt"
    out_dir="/home/pagag24/projects/def-amichaud/share/GutBrain/BIDS_results2/3dLmer/effect_maps_${contrast}"
    output_prefix="LME_longitudinal_${contrast}"
    datatable_name="LME_longitudinal_datatable_${contrast}.txt"
    AFNI_MASK="group_mask_50pct"
    echo "No suffix specified - using default output directory"
fi

echo "Data table: $data_table_file"
echo "Output directory: $out_dir"
echo "Output prefix: $output_prefix"
echo "Datatable name: $datatable_name"
echo ""

# Ensure output directory exists
mkdir -p "$out_dir"

# Work in the data directory (like your working script)
cd "$out_dir"

# Set R environment
#export R_LIBS_USER=~/R/x86_64-pc-linux-gnu-library/4.3
#export R_LIBS=~/R/x86_64-pc-linux-gnu-library/4.3

echo "Working directory: $(pwd)"
echo "Files available: $(ls *.nii* 2>/dev/null | wc -l)"
echo ""

# Clean up previous attempts
rm -f ${output_prefix}*
rm -f group_mask_50pct*

# Check if data table exists, if not try to find it
DATA_TABLE_PATH=""
if [ -f "$data_table_file" ]; then
    DATA_TABLE_PATH="$data_table_file"
    echo "✅ Found data table in current directory: $data_table_file"
elif [ -f "/home/pagag24/projects/def-amichaud/share/GutBrain/fmri/results/$data_table_file" ]; then
    DATA_TABLE_PATH="/home/pagag24/projects/def-amichaud/share/GutBrain/fmri/results/$data_table_file"
    echo "✅ Found data table in results directory: $DATA_TABLE_PATH"
    cp "$DATA_TABLE_PATH" .
else
    echo "❌ ERROR: Data table not found: $data_table_file"
    echo "Looked in:"
    echo "  - $(pwd)"
    echo "  - /home/pagag24/projects/def-amichaud/share/GutBrain/fmri/results/"
    exit 1
fi

# Copy to working name
cp "$data_table_file" "${datatable_name}"

# DEBUG: Check first data line
echo "=== DEBUGGING FILE PATH ISSUE ==="
FIRST_FILE=$(awk 'NR==2 {print $NF}' "${datatable_name}")
echo "First file path from table:"
echo "[$FIRST_FILE]"
echo "Length: ${#FIRST_FILE}"
echo "Hexdump of path:"
echo -n "$FIRST_FILE" | od -A n -t x1 | head -c 100
echo ""
echo "Testing with [ -f ]:"
if [ -f "$FIRST_FILE" ]; then
    echo "✓ File exists"
else
    echo "✗ File does NOT exist"
    echo "Trying ls directly:"
    ls "$FIRST_FILE" 2>&1
fi
echo "=== END DEBUG ==="
echo ""

# Filter using pure bash - more reliable
echo "Filtering data table to keep only rows with existing files..."
head -n 1 "${datatable_name}" > "${datatable_name}.filtered.txt"

FOUND=0
MISSING=0

while IFS=$'\t' read -r line; do
    # Get last field (InputFile column)
    inputfile=$(echo "$line" | awk '{print $NF}')

    if [ -f "$inputfile" ]; then
        echo "$line" >> "${datatable_name}.filtered.txt"
        ((FOUND++))
    else
        echo "Missing: $inputfile" >&2
        ((MISSING++))

        # Debug first missing file
        if [ $MISSING -eq 1 ]; then
            echo "=== DEBUGGING FIRST MISSING FILE ===" >&2
            echo "Path: [$inputfile]" >&2
            echo "Length: ${#inputfile}" >&2
            echo -n "$inputfile" | od -A n -t x1 | head -c 100 >&2
            echo "" >&2
        fi
    fi
done < <(tail -n +2 "${datatable_name}")

echo "Files found: $FOUND"
echo "Files missing: $MISSING"

mv "${datatable_name}.filtered.txt" "${datatable_name}"

echo ""
echo "Using data table: $data_table_file"
echo "Preview (first 10 rows):"
head -n 11 "${datatable_name}"
echo ""
echo "Total rows: $(wc -l < ${datatable_name})"

# Check if we have any data
DATA_ROWS=$(($(wc -l < "${datatable_name}") - 1))
if [ $DATA_ROWS -eq 0 ]; then
    echo "❌ ERROR: No valid data rows after filtering!"
    exit 1
fi



echo ""
echo "Creating 50% overlap mask using 3dmask_tool..."

# Check if we already have the AFNI mask
if [ -f "${AFNI_MASK}+tlrc.HEAD" ] || [ -f "${AFNI_MASK}+orig.HEAD" ]; then
    if [ -f "${AFNI_MASK}+tlrc.HEAD" ]; then
        echo "✅ AFNI mask already exists: ${AFNI_MASK}+tlrc"
        AFNI_MASK="${AFNI_MASK}+tlrc"
    else
        echo "✅ AFNI mask already exists: ${AFNI_MASK}+orig"
        AFNI_MASK="${AFNI_MASK}+orig"
    fi
else
    echo "Computing 50% overlap mask from input data..."

    EFFECT_FILES=$(awk 'NR>1 {print $NF}' "${datatable_name}" | tr '\n' ' ')
    NUM_FILES=$(echo "$EFFECT_FILES" | wc -w)

    if [ $NUM_FILES -eq 0 ]; then
        echo "❌ ERROR: No effect size map files found for mask creation"
        exit 1
    fi

    echo "Found $NUM_FILES effect size map files"
    echo "Sample files:"
    echo "$EFFECT_FILES" | tr ' ' '\n' | head -5
    echo "..."

    echo "Creating 50% overlap mask from ALL effect size maps..."
    echo "Using all $NUM_FILES files for mask creation"

    3dmask_tool -input $EFFECT_FILES -prefix $AFNI_MASK -frac 0.5 -overwrite

    if [ -f "${AFNI_MASK}+tlrc.HEAD" ]; then
        echo "✅ AFNI mask created successfully: ${AFNI_MASK}+tlrc"
        AFNI_MASK="${AFNI_MASK}+tlrc"
    elif [ -f "${AFNI_MASK}+orig.HEAD" ]; then
        echo "✅ AFNI mask created successfully: ${AFNI_MASK}+orig"
        AFNI_MASK="${AFNI_MASK}+orig"
    else
        echo "❌ Failed to create AFNI mask. Continuing without mask..."
        AFNI_MASK=""
    fi
fi

# Set mask variable
if [ -n "$AFNI_MASK" ]; then
    MASK_UNZIPPED="$AFNI_MASK"
else
    MASK_UNZIPPED=""
fi

echo ""
echo "=== MASK INFORMATION ==="
if [ -n "$MASK_UNZIPPED" ] && ([ -f "${MASK_UNZIPPED}.HEAD" ] || [ -f "${MASK_UNZIPPED}+tlrc.HEAD" ] || [ -f "${MASK_UNZIPPED}+orig.HEAD" ]); then
    echo "Using mask: $MASK_UNZIPPED"
    echo "Mask dimensions:"
    3dinfo -d3 -o3 $MASK_UNZIPPED

    MASK_VOXELS=$(3dBrickStat -count -non-zero $MASK_UNZIPPED)
    echo "Number of voxels in mask: $MASK_VOXELS"
else
    echo "No mask will be used."
fi


echo ""
echo "Running 3dLMEr with longitudinal model (with sess*twl_rech_24 interaction)..."
echo "Using $SLURM_CPUS_PER_TASK CPUs for parallel processing..."

if [ -n "$MASK_UNZIPPED" ] && ([ -f "${MASK_UNZIPPED}.HEAD" ] || [ -f "${MASK_UNZIPPED}+tlrc.HEAD" ] || [ -f "${MASK_UNZIPPED}+orig.HEAD" ]); then
    3dLMEr \
-prefix $output_prefix \
-mask $MASK_UNZIPPED \
-resid ${output_prefix}_residuals \
-jobs $SLURM_CPUS_PER_TASK \
-model "1+sess*twl_rech_24+type_chx+sex+bmi_baseline+age_baseline+handedness+vas_debut+run+(1|Subj)" \
-qVars "vas_debut,age_baseline,bmi_baseline,twl_rech_24" \
-gltCode sess1 'sess : 1*1' \
-gltCode sess2 'sess : 1*2' \
-gltCode sess3 'sess : 1*3' \
-gltCode sess4 'sess : 1*4' \
-gltCode sess2_vs_sess1 'sess : 1*2 -1*1' \
-gltCode sess3_vs_sess1 'sess : 1*3 -1*1' \
-gltCode sess4_vs_sess1 'sess : 1*4 -1*1' \
-gltCode sess1_x_twl24 'sess : 1*1 twl_rech_24 :' \
-gltCode sess2_x_twl24 'sess : 1*2 twl_rech_24 :' \
-gltCode sess3_x_twl24 'sess : 1*3 twl_rech_24 :' \
-gltCode sess4_x_twl24 'sess : 1*4 twl_rech_24 :' \
-gltCode sess2_vs_sess1_x_twl24 'sess : 1*2 -1*1 twl_rech_24 :' \
-gltCode sess3_vs_sess1_x_twl24 'sess : 1*3 -1*1 twl_rech_24 :' \
-gltCode sess4_vs_sess1_x_twl24 'sess : 1*4 -1*1 twl_rech_24 :' \
-gltCode type_chx_2_vs_1 'type_chx : 1*2 -1*1' \
-gltCode type_chx_3_vs_1 'type_chx : 1*3 -1*1' \
-gltCode sex_female_vs_male 'sex : 1*female -1*male' \
-gltCode bmi_baseline 'bmi_baseline :' \
-gltCode age_baseline 'age_baseline :' \
-gltCode handedness_left_vs_right 'handedness : 1*left -1*right' \
-gltCode vas_debut 'vas_debut :' \
-gltCode twl_rech_24 'twl_rech_24 :' \
-gltCode run_2_vs_1 'run : 1*2 -1*1' \
-gltCode run_3_vs_1 'run : 1*3 -1*1' \
-dataTable @${datatable_name}
else
    3dLMEr \
-prefix $output_prefix \
-resid ${output_prefix}_residuals \
-jobs $SLURM_CPUS_PER_TASK \
-model "1+sess*twl_rech_24+type_chx+sex+bmi_baseline+age_baseline+handedness+vas_debut+run+(1|Subj)" \
-qVars "vas_debut,age_baseline,bmi_baseline,twl_rech_24" \
-gltCode sess1 'sess : 1*1' \
-gltCode sess2 'sess : 1*2' \
-gltCode sess3 'sess : 1*3' \
-gltCode sess4 'sess : 1*4' \
-gltCode sess2_vs_sess1 'sess : 1*2 -1*1' \
-gltCode sess3_vs_sess1 'sess : 1*3 -1*1' \
-gltCode sess4_vs_sess1 'sess : 1*4 -1*1' \
-gltCode sess1_x_twl24 'sess : 1*1 twl_rech_24 :' \
-gltCode sess2_x_twl24 'sess : 1*2 twl_rech_24 :' \
-gltCode sess3_x_twl24 'sess : 1*3 twl_rech_24 :' \
-gltCode sess4_x_twl24 'sess : 1*4 twl_rech_24 :' \
-gltCode sess2_vs_sess1_x_twl24 'sess : 1*2 -1*1 twl_rech_24 :' \
-gltCode sess3_vs_sess1_x_twl24 'sess : 1*3 -1*1 twl_rech_24 :' \
-gltCode sess4_vs_sess1_x_twl24 'sess : 1*4 -1*1 twl_rech_24 :' \
-gltCode type_chx_2_vs_1 'type_chx : 1*2 -1*1' \
-gltCode type_chx_3_vs_1 'type_chx : 1*3 -1*1' \
-gltCode sex_female_vs_male 'sex : 1*female -1*male' \
-gltCode bmi_baseline 'bmi_baseline :' \
-gltCode age_baseline 'age_baseline :' \
-gltCode handedness_left_vs_right 'handedness : 1*left -1*right' \
-gltCode vas_debut 'vas_debut :' \
-gltCode twl_rech_24 'twl_rech_24 :' \
-gltCode run_2_vs_1 'run : 1*2 -1*1' \
-gltCode run_3_vs_1 'run : 1*3 -1*1' \
-dataTable @${datatable_name}
fi

echo ""
echo "=== CHECKING OUTPUT FILES ==="
ls -lat | head -20

if [ -f "${output_prefix}+tlrc.HEAD" ]; then
    echo "🎉 SUCCESS! 3dLMEr completed successfully!"
    ls -la ${output_prefix}*
else
    echo "❌ Analysis failed. Check error logs."
fi

echo ""
echo "Job ID: $SLURM_JOB_ID"
echo "End time: $(date)"
echo "Output files: $(pwd)"
