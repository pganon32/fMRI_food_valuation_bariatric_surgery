#!/bin/bash
#SBATCH --job-name=3dLMEr_longitudinal
#SBATCH --time=1:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=100G
#SBATCH --output=3dLMEr_longitudinal_%j.out
#SBATCH --error=3dLMEr_longitudinal_%j.err

echo " WORKING 3dLMEr Analysis - Longitudinal Food Auction Task "
echo "Job ID: $SLURM_JOB_ID"
echo "Running on: $SLURM_NODELIST"
echo "CPUs allocated: $SLURM_CPUS_PER_TASK"
echo "Memory allocated: 100GB"
echo "Time limit: 1 hour"
echo ""

module load apptainer
module load afni/23.3.02

# Define contrast variable
contrast="mod_hi_vs_mod_lo_v7_literature_complex_psc"

# Define suffix (e.g., "qc_final", "removed_hunger", "no_covariates", etc.)
# Edit this each time you want to create a different version
suffix="qc_final_covar"  # Set to "" for no suffix

# Build output directory with optional suffix
if [ -n "$suffix" ]; then
    out_dir="/home/pagag24/projects/def-amichaud/share/GutBrain/BIDS_results2/3dLmer/effect_maps_${contrast}_${suffix}"
    echo "Using suffix: $suffix"
else
    out_dir="/home/pagag24/projects/def-amichaud/share/GutBrain/BIDS_results2/3dLmer/effect_maps_${contrast}"
    echo "No suffix specified - using default output directory"
fi

echo "Output directory: $out_dir"
echo ""

# Ensure output directory exists
mkdir -p "$out_dir"

# Work in the data directory
cd "$out_dir"

# Set R environment
#export R_LIBS_USER=~/R/x86_64-pc-linux-gnu-library/4.3
#export R_LIBS=~/R/x86_64-pc-linux-gnu-library/4.3

echo "Working directory: $(pwd)"
echo "Files available: $(ls *.nii* 2>/dev/null | wc -l)"
echo ""

# Clean up previous attempts
rm -f LME_longitudinal_${contrast}_${suffix}*
rm -f group_mask_50pct*

# Construct data table filename with suffix
if [ -n "$suffix" ]; then
    data_table="3dlmerdata_table_with_covariates_${contrast}_${suffix}.txt"
else
    data_table="3dlmerdata_table_with_covariates_${contrast}.txt"
fi

echo "Looking for data table: $data_table"

# Use provided data table with covariates
cp "$data_table" LME_longitudinal_datatable_${contrast}_${suffix}.txt

# DEBUG: Check first data line
echo "=== DEBUGGING FILE PATH ISSUE ==="
FIRST_FILE=$(awk 'NR==2 {print $NF}' LME_longitudinal_datatable_${contrast}_${suffix}.txt)
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
head -n 1 LME_longitudinal_datatable_${contrast}_${suffix}.txt > LME_longitudinal_datatable_${contrast}_${suffix}.filtered.txt

FOUND=0
MISSING=0

while IFS=$'\t' read -r line; do
    # Get last field (InputFile column)
    inputfile=$(echo "$line" | awk '{print $NF}')

    if [ -f "$inputfile" ]; then
        echo "$line" >> LME_longitudinal_datatable_${contrast}_${suffix}.filtered.txt
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
done < <(tail -n +2 LME_longitudinal_datatable_${contrast}_${suffix}.txt)

echo "Files found: $FOUND"
echo "Files missing: $MISSING"

mv LME_longitudinal_datatable_${contrast}_${suffix}.filtered.txt LME_longitudinal_datatable_${contrast}_${suffix}.txt

echo ""
echo "Using data table: $data_table"
echo "Preview (first 10 rows):"
head -n 11 LME_longitudinal_datatable_${contrast}_${suffix}.txt
echo ""
echo "Total rows: $(wc -l < LME_longitudinal_datatable_${contrast}_${suffix}.txt)"

# Check if we have any data
DATA_ROWS=$(($(wc -l < LME_longitudinal_datatable_${contrast}_${suffix}.txt) - 1))
if [ $DATA_ROWS -eq 0 ]; then
    echo "❌ ERROR: No valid data rows after filtering!"
    exit 1
fi

echo ""
echo "Creating 50% overlap mask using 3dmask_tool..."

# Define mask filename with suffix
if [ -n "$suffix" ]; then
    AFNI_MASK="group_mask_50pct_${suffix}"
else
    AFNI_MASK="group_mask_50pct"
fi

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

    EFFECT_FILES=$(awk 'NR>1 {print $NF}' LME_longitudinal_datatable_${contrast}_${suffix}.txt | tr '\n' ' ')
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
echo "Running 3dLMEr with longitudinal model..."
echo "Using $SLURM_CPUS_PER_TASK CPUs for parallel processing..."

# Construct output prefix with suffix
if [ -n "$suffix" ]; then
    output_prefix="LME_longitudinal_${contrast}_${suffix}"
else
    output_prefix="LME_longitudinal_${contrast}"
fi

if [ -n "$MASK_UNZIPPED" ] && ([ -f "${MASK_UNZIPPED}.HEAD" ] || [ -f "${MASK_UNZIPPED}+tlrc.HEAD" ] || [ -f "${MASK_UNZIPPED}+orig.HEAD" ]); then
    3dLMEr \
-prefix $output_prefix \
-mask $MASK_UNZIPPED \
-resid ${output_prefix}_residuals \
-jobs $SLURM_CPUS_PER_TASK \
-model "1+sess+type_chx+sex+bmi_baseline+age_baseline+handedness+run+(1|Subj)" \
-qVars "vas_debut,age_baseline,bmi_baseline" \
-gltCode sess1 'sess : 1*1' \
-gltCode sess2 'sess : 1*2' \
-gltCode sess3 'sess : 1*3' \
-gltCode sess4 'sess : 1*4' \
-gltCode sess2_vs_sess1 'sess : 1*2 -1*1' \
-gltCode sess3_vs_sess1 'sess : 1*3 -1*1' \
-gltCode sess4_vs_sess1 'sess : 1*4 -1*1' \
-gltCode type_chx_2_vs_1 'type_chx : 1*2 -1*1' \
-gltCode type_chx_3_vs_1 'type_chx : 1*3 -1*1' \
-gltCode sex_female_vs_male 'sex : 1*female -1*male' \
-gltCode bmi_baseline 'bmi_baseline :' \
-gltCode age_baseline 'age_baseline :' \
-gltCode handedness_left_vs_right 'handedness : 1*left -1*right' \
-gltCode run_2_vs_1 'run : 1*2 -1*1' \
-gltCode run_3_vs_1 'run : 1*3 -1*1' \
-dataTable @LME_longitudinal_datatable_${contrast}_${suffix}.txt
else
    3dLMEr \
-prefix $output_prefix \
-resid ${output_prefix}_residuals \
-jobs $SLURM_CPUS_PER_TASK \
-model "1+sess+type_chx+sex+bmi_baseline+age_baseline+handedness+run+(1|Subj)" \
-qVars "vas_debut,age_baseline,bmi_baseline" \
-gltCode sess1 'sess : 1*1' \
-gltCode sess2 'sess : 1*2' \
-gltCode sess3 'sess : 1*3' \
-gltCode sess4 'sess : 1*4' \
-gltCode sess2_vs_sess1 'sess : 1*2 -1*1' \
-gltCode sess3_vs_sess1 'sess : 1*3 -1*1' \
-gltCode sess4_vs_sess1 'sess : 1*4 -1*1' \
-gltCode type_chx_2_vs_1 'type_chx : 1*2 -1*1' \
-gltCode type_chx_3_vs_1 'type_chx : 1*3 -1*1' \
-gltCode sex_female_vs_male 'sex : 1*female -1*male' \
-gltCode bmi_baseline 'bmi_baseline :' \
-gltCode age_baseline 'age_baseline :' \
-gltCode handedness_left_vs_right 'handedness : 1*left -1*right' \
-gltCode run_2_vs_1 'run : 1*2 -1*1' \
-gltCode run_3_vs_1 'run : 1*3 -1*1' \
-dataTable @LME_longitudinal_datatable_${contrast}_${suffix}.txt
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
