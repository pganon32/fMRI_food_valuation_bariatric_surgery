#!/bin/bash

# Script to extract mean beta estimates from first-level contrast maps within AFNI clusters or Yeo7 parcels
# Outputs results in BIDS format data table

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Required Arguments:
  --bids-dir DIR          Path to BIDS results directory containing subject folders
  --contrast STR          Substring to identify first-level contrast files (e.g., "mod_hi_vs_mod_lo")
                          NOTE: Script will automatically filter for files containing "effect-size"
  --output-dir DIR        Path to output directory (contains cluster file and will store results table)
  
Mask Options (choose one):
  --cluster STR|PATH      Substring to identify cluster mask files (e.g., "clustered")
                          OR full path to cluster mask file
                          OR relative path from BIDS directory (e.g., "3dLmer/results/result_folder/cluster_file.nii.gz")
  --yeo7                  Use Yeo 7-network parcellation atlas instead of cluster masks
  
Optional Arguments:
  --mock                  Mock mode - print operations without computing
  --participants STR      Comma-separated list of participant IDs (e.g., "sub-01,sub-02,sub-03")
                          If not specified, all participants will be processed
  --sessions STR          Comma-separated list of session IDs (e.g., "ses-01,ses-02")
                          If not specified, all sessions will be processed
  --clean                 Remove previous beta_estimates_*.tsv files before processing
  --scratch-temps         Save temporary resampled files to SCRATCH directory for inspection
  --ncores N              Number of parallel processes (default: 1, use 0 for auto-detect)
  --help                  Display this help message

Example:
  # Process with cluster mask using 8 cores
  $0 --bids-dir ~/projects/def-amichaud/share/GutBrain/BIDS_results2/ --contrast "mod_hi_vs_mod_lo_v7_literature_complex_psc" --cluster "sess1_x_twl24_clustered" --output-dir ~/projects/def-amichaud/share/GutBrain/BIDS_results2/3dLmer/results/mod_hi_vs_mod_lo_v7_literature_complex_psc_twl_24_qc_final/ --ncores 8

  # Process with Yeo7 parcellation using all available cores
  $0 --bids-dir ~/projects/def-amichaud/share/GutBrain/BIDS_results2/ --contrast "mod_hi_vs_mod_lo_v7_literature_complex_psc" --yeo7 --output-dir ~/projects/def-amichaud/share/GutBrain/BIDS_results2/3dLmer/results/mod_hi_vs_mod_lo_v7_literature_complex_psc_twl_24_qc_final/ --ncores 0 --scratch-temps

EOF
    exit 1
}

# Initialize variables
BIDS_DIR=""
CONTRAST=""
CLUSTER=""
OUTPUT_DIR=""
MOCK_MODE=0
PARTICIPANTS=""
SESSIONS=""
CLEAN_MODE=0
USE_YEO7=0
SAVE_TEMPS=0
NCORES=1

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --bids-dir)
            BIDS_DIR="$2"
            shift 2
            ;;
        --contrast)
            CONTRAST="$2"
            shift 2
            ;;
        --cluster)
            CLUSTER="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --yeo7)
            USE_YEO7=1
            shift
            ;;
        --mock)
            MOCK_MODE=1
            shift
            ;;
        --participants)
            PARTICIPANTS="$2"
            shift 2
            ;;
        --sessions)
            SESSIONS="$2"
            shift 2
            ;;
        --clean)
            CLEAN_MODE=1
            shift
            ;;
        --scratch-temps)
            SAVE_TEMPS=1
            shift
            ;;
        --ncores)
            NCORES="$2"
            shift 2
            ;;
        --help)
            usage
            ;;
        *)
            echo "Error: Unknown option $1"
            usage
            ;;
    esac
done

# Check required arguments
if [[ -z "$BIDS_DIR" ]] || [[ -z "$CONTRAST" ]] || [[ -z "$OUTPUT_DIR" ]]; then
    echo "Error: Missing required arguments"
    usage
fi

# Check that either --cluster or --yeo7 is specified
if [[ -z "$CLUSTER" ]] && [[ $USE_YEO7 -eq 0 ]]; then
    echo "Error: Must specify either --cluster or --yeo7"
    usage
fi

# Check that both options are not specified
if [[ -n "$CLUSTER" ]] && [[ $USE_YEO7 -eq 1 ]]; then
    echo "Error: Cannot specify both --cluster and --yeo7"
    usage
fi

# Check if BIDS directory exists
if [[ ! -d "$BIDS_DIR" ]]; then
    echo "Error: BIDS directory does not exist: $BIDS_DIR"
    exit 1
fi

# Check if output directory exists
if [[ ! -d "$OUTPUT_DIR" ]]; then
    echo "Error: Output directory does not exist: $OUTPUT_DIR"
    exit 1
fi

# Remove trailing slash from OUTPUT_DIR if present
OUTPUT_DIR="${OUTPUT_DIR%/}"

# Auto-detect number of cores if requested
if [[ $NCORES -eq 0 ]]; then
    NCORES=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 1)
    echo "Auto-detected $NCORES cores"
fi

# Setup scratch directory for temporary files if requested
if [[ $SAVE_TEMPS -eq 1 ]]; then
    if [[ -z "$SCRATCH" ]]; then
        echo "Error: SCRATCH environment variable not set"
        echo "Please set SCRATCH to your scratch directory path"
        exit 1
    fi
    
    TEMP_DIR="${SCRATCH}/extract_beta_temps_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$TEMP_DIR"
    echo "Temporary files will be saved to: $TEMP_DIR"
    echo ""
fi

# Clean up previous beta estimate files if requested
if [[ $CLEAN_MODE -eq 1 ]]; then
    echo "======================================"
    echo "Cleaning up previous beta estimate files..."
    echo "======================================"
    old_files=$(find "$OUTPUT_DIR" -type f -name "beta_estimates_*.tsv" 2>/dev/null)
    if [[ -n "$old_files" ]]; then
        echo "$old_files" | while read -r file; do
            echo "Removing: $(basename "$file")"
            rm -f "$file"
        done
        echo "Cleanup complete!"
    else
        echo "No previous beta estimate files found."
    fi
    echo ""
fi

# Handle mask file setup
if [[ $USE_YEO7 -eq 1 ]]; then
    # Use existing 3mm Yeo7 atlas
    YEO7_FILE="$HOME/nilearn_data/yeo_2011/Yeo_JNeurophysiol11_MNI152/Yeo2011_7Networks_MNI152_FreeSurferConformed3mm_LiberalMask.nii.gz"
    
    # Check if atlas exists
    if [[ ! -f "$YEO7_FILE" ]]; then
        echo "Error: Yeo7 atlas not found at: $YEO7_FILE"
        echo ""
        echo "Please ensure the atlas file exists at the expected location."
        exit 1
    fi
    
    echo "Using Yeo7 atlas: $YEO7_FILE"
    echo ""
    echo "NOTE: For Yeo7 analysis, contrast files will be resampled to the atlas space"
    echo "      This ensures consistent network definitions across all subjects/runs"
    echo ""
    
    cluster_file="$YEO7_FILE"
    
    mask_type="yeo7"
    CLUSTER="yeo7"
    
    # Define network names for Yeo7
    declare -A YEO7_NETWORKS
    YEO7_NETWORKS[1]="Visual"
    YEO7_NETWORKS[2]="Somatomotor"
    YEO7_NETWORKS[3]="DorsalAttention"
    YEO7_NETWORKS[4]="VentralAttention"
    YEO7_NETWORKS[5]="Limbic"
    YEO7_NETWORKS[6]="Frontoparietal"
    YEO7_NETWORKS[7]="DefaultMode"
    
else
    # Check if CLUSTER is a full path (absolute or relative from current directory)
    if [[ -f "$CLUSTER" ]]; then
        cluster_file="$CLUSTER"
        echo "Using cluster file from provided path: $cluster_file"
    # Check if CLUSTER is relative to BIDS_DIR
    elif [[ -f "${BIDS_DIR}/${CLUSTER}" ]]; then
        cluster_file="${BIDS_DIR}/${CLUSTER}"
        echo "Using cluster file from BIDS directory: $cluster_file"
    else
        # Original behavior: search in output directory using substring
        cluster_file=$(find "$OUTPUT_DIR" -type f -name "*${CLUSTER}*.nii*" | head -n 1)
        
        if [[ -z "$cluster_file" ]]; then
            echo "Error: No cluster file found:"
            echo "  - Not found as direct path: $CLUSTER"
            echo "  - Not found relative to BIDS directory: ${BIDS_DIR}/${CLUSTER}"
            echo "  - Not found in output directory matching: *${CLUSTER}*.nii*"
            exit 1
        fi
        
        echo "Found cluster file using substring search: $cluster_file"
    fi
    
    # Look for MNI version in atlas_coverage_reports subfolder
    cluster_basename=$(basename "$cluster_file" .nii.gz)
    mni_cluster_file="${OUTPUT_DIR}/atlas_coverage_reports/${cluster_basename}_MNI.nii.gz"
    
    # ...existing code...
    
    mask_type="cluster"
fi

# Convert comma-separated lists to arrays
if [[ -n "$PARTICIPANTS" ]]; then
    IFS=',' read -ra PARTICIPANT_ARRAY <<< "$PARTICIPANTS"
else
    PARTICIPANT_ARRAY=()
fi

if [[ -n "$SESSIONS" ]]; then
    IFS=',' read -ra SESSION_ARRAY <<< "$SESSIONS"
else
    SESSION_ARRAY=()
fi

# Build output filename based on mask type
if [[ $USE_YEO7 -eq 1 ]]; then
    output_basename="beta_estimates_yeo7"
else
    # Extract just the basename of the cluster file (without path and extension)
    cluster_basename=$(basename "$cluster_file" .nii.gz)
    cluster_basename=$(basename "$cluster_basename" .nii)
    output_basename="beta_estimates_${cluster_basename}"
fi

# Add participant filter info if specified
if [[ ${#PARTICIPANT_ARRAY[@]} -gt 0 ]]; then
    num_participants=${#PARTICIPANT_ARRAY[@]}
    output_basename="${output_basename}_n${num_participants}participants"
fi

# Add session filter info if specified
if [[ ${#SESSION_ARRAY[@]} -gt 0 ]]; then
    session_filter=$(echo "${SESSIONS}" | tr ',' '-')
    output_basename="${output_basename}_${session_filter}"
fi

# Add timestamp
output_basename="${output_basename}_$(date +%Y%m%d_%H%M%S)"

# Define output TSV file
OUTPUT_FILE="${OUTPUT_DIR}/${output_basename}.tsv"

# Create temporary directory for per-participant results
TEMP_RESULTS_DIR=$(mktemp -d /tmp/beta_results_XXXXXX)

# Write header to output file with network name if using Yeo7
if [[ $USE_YEO7 -eq 1 ]]; then
    echo -e "participant_id\tsession\trun\tcontrast\tnetwork_id\tnetwork_name\tnetwork_size\tcom_mni_x\tcom_mni_y\tcom_mni_z\tmean_beta\tstd_beta\tmin_beta\tmax_beta" > "$OUTPUT_FILE"
else
    echo -e "participant_id\tsession\trun\tcontrast\tcluster_id\tcluster_size\tcom_mni_x\tcom_mni_y\tcom_mni_z\tmean_beta\tstd_beta\tmin_beta\tmax_beta" > "$OUTPUT_FILE"
fi

echo "======================================"
echo "AFNI Beta Extraction Script"
echo "======================================"
echo "BIDS Directory: $BIDS_DIR"
echo "Contrast substring: $CONTRAST"
echo "Effect-size filter: ENABLED (only files with 'effect-size' will be processed)"
if [[ $USE_YEO7 -eq 1 ]]; then
    echo "Mask type: Yeo 7-Network Parcellation"
    echo "Atlas file: $(basename $cluster_file)"
else
    echo "Mask type: Cluster mask"
    echo "Cluster file: $(basename $cluster_file)"
    echo "Cluster file full path: $cluster_file"
fi
echo "Output Directory: $OUTPUT_DIR"
echo "Mock Mode: $([[ $MOCK_MODE -eq 1 ]] && echo "YES" || echo "NO")"
echo "Save temps: $([[ $SAVE_TEMPS -eq 1 ]] && echo "YES (to $TEMP_DIR)" || echo "NO")"
echo "Parallel cores: $NCORES"
if [[ ${#PARTICIPANT_ARRAY[@]} -gt 0 ]]; then
    echo "Filtering participants: ${PARTICIPANTS}"
else
    echo "Processing all participants"
fi
if [[ ${#SESSION_ARRAY[@]} -gt 0 ]]; then
    echo "Filtering sessions: ${SESSIONS}"
else
    echo "Processing all sessions"
fi
echo "======================================"
echo ""

# Function to check if participant should be processed
should_process_participant() {
    local participant=$1
    if [[ ${#PARTICIPANT_ARRAY[@]} -eq 0 ]]; then
        return 0  # Process all if no filter specified
    fi
    for p in "${PARTICIPANT_ARRAY[@]}"; do
        if [[ "$participant" == "$p" ]]; then
            return 0
        fi
    done
    return 1
}

# Function to check if session should be processed
should_process_session() {
    local session=$1
    if [[ ${#SESSION_ARRAY[@]} -eq 0 ]]; then
        return 0  # Process all if no filter specified
    fi
    for s in "${SESSION_ARRAY[@]}"; do
        if [[ "$session" == "$s" ]]; then
            return 0
        fi
    done
    return 1
}

# Function to process a single participant
process_participant() {
    local sub_dir=$1
    local participant_id=$(basename "$sub_dir")
    local participant_output="${TEMP_RESULTS_DIR}/${participant_id}.tsv"
    
    echo "Processing $participant_id..."
    
    # Find all session directories (ses-*)
    for ses_dir in "$sub_dir"/ses-* "$sub_dir"; do
        if [[ ! -d "$ses_dir" ]]; then
            continue
        fi
        
        # Extract session ID or use "ses-01" as default if no session structure
        if [[ "$ses_dir" == *"/ses-"* ]]; then
            session=$(basename "$ses_dir")
        else
            session="ses-01"
        fi
        
        # Check if session should be processed
        if ! should_process_session "$session"; then
            echo "  Skipping $session (not in filter list)"
            continue
        fi
        
        echo "  Session: $session"
        
        # Find all contrast files matching the substring AND containing "effect-size"
        while IFS= read -r contrast_file; do
            if [[ -z "$contrast_file" ]]; then
                continue
            fi
            
            contrast_basename=$(basename "$contrast_file")
            
            # CRITICAL: Only process files that contain "effect-size" in the filename
            if [[ ! "$contrast_basename" =~ effect-size ]]; then
                echo "      Skipping (no effect-size): $contrast_basename"
                continue
            fi
            
            echo "      Processing contrast: $contrast_basename"
            
            # Extract run information if present in filename
            if [[ "$contrast_basename" =~ run-([0-9]+) ]]; then
                run="run-${BASH_REMATCH[1]}"
            else
                run="run-01"
            fi
            
            if [[ $MOCK_MODE -eq 1 ]]; then
                echo "        [MOCK] Would compute mean beta estimates:"
                echo "        [MOCK]   - Contrast file: $contrast_file"
                echo "        [MOCK]   - Mask: $cluster_file"
                echo "        [MOCK]   - Mask type: $mask_type"
                echo "        [MOCK]   - Participant: $participant_id"
                echo "        [MOCK]   - Session: $session"
                echo "        [MOCK]   - Run: $run"
                if [[ $USE_YEO7 -eq 1 ]]; then
                    echo "        [MOCK] Would process networks 1-7"
                fi
                echo "        [MOCK] Would execute: 3dROIstats -mask $cluster_file -nzmean -nzsigma -nzmin -nzmax $contrast_file"
                echo "        [MOCK] Would execute: 3dCenterMass for center of mass coordinates"
                echo "        [MOCK] Would save results to: $participant_output"
            
            else

                # Determine which ROIs to process
                if [[ $USE_YEO7 -eq 1 ]]; then
                    # For Yeo7, process networks 1-7
                    cluster_vals="1 2 3 4 5 6 7"
                else
                    # Get unique cluster values from mask using 3dROIstats
                    echo "        Querying cluster mask for ROI IDs..."
                    roi_output=$(3dROIstats -mask "$cluster_file" -nzvoxels "$cluster_file" 2>&1)
                    echo "        Raw 3dROIstats output: $roi_output"
                    
                    cluster_vals=$(echo "$roi_output" | head -n 1 | grep -oE 'Mean_[0-9]+' | grep -oE '[0-9]+' | sort -n -u)
                    
                    if [[ -z "$cluster_vals" ]]; then
                        echo "        WARNING: No clusters found in mask file"
                        echo "        Attempting alternative method..."
                        
                        # Try alternative: get max value and create sequence
                        max_val=$(3dBrickStat -slow -max "$cluster_file" 2>/dev/null)
                        if [[ -n "$max_val" ]] && [[ "$max_val" != "0" ]]; then
                            cluster_vals=$(seq 1 $max_val)
                            echo "        Using sequence method: found $max_val clusters"
                        else
                            echo "        ERROR: Could not determine cluster IDs"
                            continue
                        fi
                    fi
                    
                    echo "        Found cluster IDs: $cluster_vals"
                fi
                
                # For Yeo7: Resample contrast to atlas space
                if [[ $USE_YEO7 -eq 1 ]]; then
                    echo "        Resampling contrast to Yeo7 atlas space..."
                    
                    # Choose temp file location based on --scratch-temps flag
                    if [[ $SAVE_TEMPS -eq 1 ]]; then
                        # Save to scratch with descriptive filename
                        resampled_basename="${contrast_basename%.nii.gz}_resampled_yeo7.nii.gz"
                        temp_resampled_contrast="${TEMP_DIR}/${participant_id}_${session}_${resampled_basename}"
                        echo "        Saving resampled file: $(basename $temp_resampled_contrast)"
                    else
                        # Use temporary file in /tmp (will be deleted)
                        temp_resampled_contrast=$(mktemp /tmp/contrast_resampled_XXXXXX.nii.gz)
                    fi
                    
                    3dresample -master "$cluster_file" -input "$contrast_file" -prefix "$temp_resampled_contrast" -rmode Linear -overwrite 2>&1 | grep -v "AFNI converts"
                    
                    if [[ ! -f "$temp_resampled_contrast" ]]; then
                        echo "        ERROR: Failed to resample contrast file"
                        continue
                    fi
                    
                    contrast_to_use="$temp_resampled_contrast"
                    atlas_to_use="$cluster_file"
                else
                    contrast_to_use="$contrast_file"
                    atlas_to_use="$cluster_file"
                fi
                
                # For each cluster/network, extract stats
                for cluster_id in $cluster_vals; do
                    # Create temporary mask for this cluster/network
                    temp_mask=$(mktemp /tmp/cluster_mask_XXXXXX.nii.gz)
                    3dcalc -a "$atlas_to_use" -expr "equals(a,$cluster_id)" -prefix "$temp_mask" -overwrite 2>&1 | grep -v "3dcalc:"
                    
                    if [[ ! -f "$temp_mask" ]]; then
                        echo "        ERROR: Failed to create mask for ROI $cluster_id"
                        continue
                    fi
                    
                    # Get cluster/network size (number of voxels)
                    cluster_size=$(3dBrickStat -count -non-zero "$temp_mask" 2>/dev/null)
                    
                    if [[ -z "$cluster_size" ]] || [[ "$cluster_size" -eq 0 ]]; then
                        echo "        WARNING: ROI $cluster_id has zero voxels, skipping"
                        rm -f "$temp_mask"
                        continue
                    fi
                    
                    # Get center of mass coordinates
                    com_output=$(3dCM "$temp_mask" 2>/dev/null)
                    com_x_raw=$(echo "$com_output" | awk '{print $1}')
                    com_y_raw=$(echo "$com_output" | awk '{print $2}')
                    com_z_raw=$(echo "$com_output" | awk '{print $3}')
                    
                    # Convert from 3dCM output to true MNI LPI coordinates by flipping X and Y signs
                    com_mni_x=$(echo "$com_x_raw" | awk '{print -$1}')
                    com_mni_y=$(echo "$com_y_raw" | awk '{print -$1}')
                    com_mni_z="$com_z_raw"
                    
                    if [[ $USE_YEO7 -eq 1 ]]; then
                        network_name="${YEO7_NETWORKS[$cluster_id]}"
                    fi

                    # Extract mean statistic
                    stats_output=$(3dROIstats -mask "$temp_mask" -quiet "$contrast_to_use" 2>/dev/null)
                    
                    if [[ -z "$stats_output" ]]; then
                        echo "        WARNING: 3dROIstats returned no output for ROI $cluster_id"
                        rm -f "$temp_mask"
                        continue
                    fi
                    
                    # Parse statistics
                    mean_beta=$(echo "$stats_output" | awk '{for(i=NF;i>=1;i--) if($i ~ /^-?[0-9]+\.?[0-9]*([eE][-+]?[0-9]+)?$/) {print $i; exit}}')
                    
                    std_output=$(3dROIstats -mask "$temp_mask" -nzsigma -quiet "$contrast_to_use" 2>/dev/null)
                    std_beta=$(echo "$std_output" | awk '{for(i=NF;i>=1;i--) if($i ~ /^-?[0-9]+\.?[0-9]*([eE][-+]?[0-9]+)?$/) {print $i; exit}}')
                    
                    minmax_output=$(3dROIstats -mask "$temp_mask" -nzminmax -quiet "$contrast_to_use" 2>/dev/null)
                    minmax_vals=($(echo "$minmax_output" | grep -oE '\-?[0-9]+\.?[0-9]*([eE][-+]?[0-9]+)?'))
                    
                    if [[ ${#minmax_vals[@]} -ge 2 ]]; then
                        min_beta="${minmax_vals[-2]}"
                        max_beta="${minmax_vals[-1]}"
                    else
                        min_beta=""
                        max_beta=""
                    fi
                    
                    # Check if we got valid numbers
                    if [[ -z "$mean_beta" ]] || ! [[ "$mean_beta" =~ ^-?[0-9]+\.?[0-9]*([eE][-+]?[0-9]+)?$ ]]; then
                        echo "        WARNING: Could not extract valid mean for ROI $cluster_id"
                        rm -f "$temp_mask"
                        continue
                    fi
                    
                    # Write to participant-specific output file
                    if [[ $USE_YEO7 -eq 1 ]]; then
                        echo -e "${participant_id}\t${session}\t${run}\t${contrast_basename}\t${cluster_id}\t${network_name}\t${cluster_size}\t${com_mni_x}\t${com_mni_y}\t${com_mni_z}\t${mean_beta}\t${std_beta}\t${min_beta}\t${max_beta}" >> "$participant_output"
                        echo "        Network $cluster_id ($network_name): mean=$mean_beta"
                    else
                        echo -e "${participant_id}\t${session}\t${run}\t${contrast_basename}\t${cluster_id}\t${cluster_size}\t${com_mni_x}\t${com_mni_y}\t${com_mni_z}\t${mean_beta}\t${std_beta}\t${min_beta}\t${max_beta}" >> "$participant_output"
                        echo "        Cluster $cluster_id: mean=$mean_beta"
                    fi
                    
                    # Clean up temporary mask
                    rm -f "$temp_mask"
                done
                
                # Clean up resampled contrast only if not saving to scratch
                if [[ $USE_YEO7 -eq 1 ]] && [[ $SAVE_TEMPS -eq 0 ]]; then
                    rm -f "$temp_resampled_contrast"
                fi

            fi
            
        done < <(find "$ses_dir" -type f -name "*${CONTRAST}*.nii*")
        
    done
    echo ""
}

# Export functions and variables needed by parallel processes
export -f process_participant
export -f should_process_session
export BIDS_DIR CONTRAST cluster_file mask_type MOCK_MODE USE_YEO7 SAVE_TEMPS TEMP_DIR
export TEMP_RESULTS_DIR
export -A YEO7_NETWORKS
export SESSION_ARRAY

# Collect all subject directories to process
subjects_to_process=()
for sub_dir in "$BIDS_DIR"/sub-*; do
    if [[ ! -d "$sub_dir" ]]; then
        continue
    fi
    
    participant_id=$(basename "$sub_dir")
    
    # Check if participant should be processed
    if ! should_process_participant "$participant_id"; then
        echo "Skipping $participant_id (not in filter list)"
        continue
    fi
    
    subjects_to_process+=("$sub_dir")
done

echo "Found ${#subjects_to_process[@]} participants to process"
echo ""


# Process participants in parallel using GNU parallel if available, otherwise use xargs
if command -v parallel &> /dev/null; then
    printf "%s\n" "${subjects_to_process[@]}" | parallel -j "$NCORES" --line-buffer process_participant {}
else
    printf "%s\n" "${subjects_to_process[@]}" | xargs -P "$NCORES" -I {} bash -c 'process_participant "$@"' _ {}
fi

# Combine all participant results into final output file
echo "======================================"
echo "Combining results from all participants..."
for participant_file in "$TEMP_RESULTS_DIR"/*.tsv; do
    if [[ -f "$participant_file" ]]; then
        cat "$participant_file" >> "$OUTPUT_FILE"
    fi
done

# Clean up temporary results directory
rm -rf "$TEMP_RESULTS_DIR"

echo "======================================"
echo "Processing complete!"
if [[ $MOCK_MODE -eq 0 ]]; then
    echo "Results saved to: $OUTPUT_FILE"
    total_rows=$(($(wc -l < "$OUTPUT_FILE") - 1))  # Subtract header
    echo "Total data rows: $total_rows"
    if [[ $SAVE_TEMPS -eq 1 ]]; then
        echo ""
        echo "Resampled files saved to: $TEMP_DIR"
        echo "Total files: $(ls -1 "$TEMP_DIR" 2>/dev/null | wc -l)"
    fi
else
    echo "Mock mode completed - no files processed"
fi
if [[ $USE_YEO7 -eq 1 ]]; then
    echo "Mask type: Yeo 7-Network Parcellation"
    echo "Atlas file: $(basename $cluster_file)"
else
    echo "Mask type: Cluster mask"
    echo "Cluster file: $(basename $cluster_file)"
    echo "Cluster file full path: $cluster_file"
fi
echo "======================================"
