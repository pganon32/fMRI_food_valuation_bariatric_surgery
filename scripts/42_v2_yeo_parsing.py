#!/usr/bin/env python3

import argparse
import sys
from pathlib import Path
import numpy as np
import pandas as pd
import nibabel as nib
from nilearn.datasets import fetch_atlas_yeo_2011
from nilearn import image as nli
import glob
from scipy import ndimage
import os
from datetime import datetime
from concurrent.futures import ProcessPoolExecutor
import multiprocessing


# ============================================================================
# Network names for Yeo7
# ============================================================================
YEO7_NETWORKS = {
    1: "Visual",
    2: "Somatomotor",
    3: "DorsalAttention",
    4: "VentralAttention",
    5: "Limbic",
    6: "Frontoparietal",
    7: "DefaultMode"
}

# ============================================================================
# Function to extract network stats from effect-size image
# ============================================================================
def extract_network_stats(effect_size_data, effect_size_affine, yeo_data, network_id):
    """
    Extract statistics for a specific Yeo network from an effect-size image.
    Uses pre-resampled Yeo data (already in effect-size image space).
    
    Returns:
        dict with keys: network_size, com_mni_x, com_mni_y, com_mni_z, 
                       mean_beta, std_beta, min_beta, max_beta
    """
    
    # Get mask for this network
    network_mask = (yeo_data == network_id)
    
    # Count non-zero voxels in this network
    network_size = np.sum(network_mask)
    
    if network_size == 0:
        return None
    
    # Extract voxel values within network
    network_values = effect_size_data[network_mask]
    
    # Remove any NaN or inf values
    network_values = network_values[np.isfinite(network_values)]
    
    if len(network_values) == 0:
        return None
    
    # Calculate statistics
    mean_beta = np.mean(network_values)
    std_beta = np.std(network_values)
    min_beta = np.min(network_values)
    max_beta = np.max(network_values)
    
    # Calculate center of mass in voxel coordinates
    com_voxel = ndimage.center_of_mass(network_mask.astype(float))
    
    # Convert to MNI coordinates using affine
    com_mni = effect_size_affine @ np.array([com_voxel[0], com_voxel[1], com_voxel[2], 1])
    
    return {
        'network_size': int(network_size),
        'com_mni_x': float(com_mni[0]),
        'com_mni_y': float(com_mni[1]),
        'com_mni_z': float(com_mni[2]),
        'mean_beta': float(mean_beta),
        'std_beta': float(std_beta),
        'min_beta': float(min_beta),
        'max_beta': float(max_beta)
    }

# ============================================================================
# Function to process a single effect-size image
# ============================================================================
def process_effect_size_file(effect_size_file, yeo_data_path, contrast_str, mock_mode=False):
    """
    Process a single effect-size image and extract Yeo 7 network statistics.
    Uses pre-resampled Yeo atlas data.
    
    Returns:
        list of dicts with results
    """
    results = []
    effect_size_file = Path(effect_size_file)
    
    # Parse filename to extract metadata
    parts = effect_size_file.parts
    
    # Find participant ID (sub-XXXX)
    participant_id = next((p for p in parts if p.startswith('sub-')), None)
    
    # Find session ID (ses-XXXX)
    session_id = next((p for p in parts if p.startswith('ses-')), None)
    
    # Extract run from filename
    filename = effect_size_file.name
    if 'run-' in filename:
        run_part = [p for p in filename.split('_') if p.startswith('run-')][0]
        run_id = run_part
    else:
        run_id = "run-01"
    
    # Extract contrast name from filename
    contrast_name = filename
    
    if mock_mode:
        print(f"  [MOCK] Processing: {contrast_name}")
        for network_id in range(1, 8):
            row = {
                'participant_id': participant_id,
                'session': session_id,
                'run': run_id,
                'contrast': contrast_name,
                'network_id': network_id,
                'network_name': YEO7_NETWORKS[network_id],
                'network_size': 0,
                'com_mni_x': 0.0,
                'com_mni_y': 0.0,
                'com_mni_z': 0.0,
                'mean_beta': 0.0,
                'std_beta': 0.0,
                'min_beta': 0.0,
                'max_beta': 0.0
            }
            results.append(row)
        return results
    
    # Load pre-resampled Yeo atlas data
    yeo_data = np.load(yeo_data_path)
    
    # Load effect-size image
    try:
        effect_img = nib.load(str(effect_size_file))
        effect_data = effect_img.get_fdata()
        effect_affine = effect_img.affine
    except Exception as e:
        print(f"  ERROR loading image: {e}", file=sys.stderr)
        return results
    
    # For each Yeo network, extract statistics
    for network_id in range(1, 8):
        stats = extract_network_stats(effect_data, effect_affine, yeo_data, network_id)
        
        if stats is None:
            continue
        
        # Create result row
        row = {
            'participant_id': participant_id,
            'session': session_id,
            'run': run_id,
            'contrast': contrast_name,
            'network_id': network_id,
            'network_name': YEO7_NETWORKS[network_id],
            'network_size': stats['network_size'],
            'com_mni_x': stats['com_mni_x'],
            'com_mni_y': stats['com_mni_y'],
            'com_mni_z': stats['com_mni_z'],
            'mean_beta': stats['mean_beta'],
            'std_beta': stats['std_beta'],
            'min_beta': stats['min_beta'],
            'max_beta': stats['max_beta']
        }
        
        results.append(row)
    
    return results


def main():
    # ========================================================================
    # Parse command-line arguments
    # ========================================================================
    parser = argparse.ArgumentParser(
        description="Extract mean beta estimates from first-level contrast maps within Yeo 7 networks",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Example:
  %(prog)s --bids-dir ~/BIDS_results2/ \\
           --contrast "mod_hi_vs_mod_lo_v7_literature_complex_psc" \\
           --output-dir ~/BIDS_results2/results/ \\
           --ncores 8

  %(prog)s --bids-dir ~/BIDS_results2/ \\
           --contrast "mod_hi_vs_mod_lo_v7_literature_complex_psc" \\
           --output-dir ~/BIDS_results2/results/ \\
           --participants sub-001,sub-002 \\
           --sessions ses-01,ses-02 \\
           --ncores 0
        """
    )
    
    # Required arguments
    parser.add_argument('--bids-dir', required=True, type=Path,
                        help='Path to BIDS results directory containing subject folders')
    parser.add_argument('--contrast', required=True, type=str,
                        help='Substring to identify first-level contrast files (e.g., "mod_hi_vs_mod_lo") '
                             '(NOTE: Script will automatically filter for files containing "effect-size")')
    parser.add_argument('--output-dir', required=True, type=Path,
                        help='Path to output directory (will store results table)')
    
    # Optional arguments
    parser.add_argument('--mock', action='store_true',
                        help='Mock mode - print operations without computing')
    parser.add_argument('--participants', type=str, default=None,
                        help='Comma-separated list of participant IDs (e.g., "sub-01,sub-02,sub-03")')
    parser.add_argument('--sessions', type=str, default=None,
                        help='Comma-separated list of session IDs (e.g., "ses-01,ses-02")')
    parser.add_argument('--clean', action='store_true',
                        help='Remove previous beta_estimates_yeo7*.tsv files before processing')
    parser.add_argument('--scratch-temps', action='store_true',
                        help='Save temporary files to SCRATCH directory for inspection')
    parser.add_argument('--ncores', type=int, default=1,
                        help='Number of parallel processes (default: 1, use 0 for auto-detect)')
    
    args = parser.parse_args()
    
    # ========================================================================
    # Validate arguments
    # ========================================================================
    if not args.bids_dir.exists():
        print(f"Error: BIDS directory does not exist: {args.bids_dir}", file=sys.stderr)
        sys.exit(1)
    
    if not args.output_dir.exists():
        print(f"Error: Output directory does not exist: {args.output_dir}", file=sys.stderr)
        sys.exit(1)
    
    # Auto-detect number of cores if requested
    if args.ncores == 0:
        args.ncores = os.cpu_count() or 1
        print(f"Auto-detected {args.ncores} cores")
    
    # Parse participant and session filters
    participant_filter = set()
    if args.participants:
        participant_filter = set(args.participants.split(','))
    
    session_filter = set()
    if args.sessions:
        session_filter = set(args.sessions.split(','))
    
    # Setup scratch directory if needed
    temp_dir = None
    if args.scratch_temps:
        scratch = os.environ.get('SCRATCH')
        if not scratch:
            print("Error: SCRATCH environment variable not set", file=sys.stderr)
            sys.exit(1)
        temp_dir = Path(scratch) / f"extract_beta_temps_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        temp_dir.mkdir(parents=True, exist_ok=True)
        print(f"Temporary files will be saved to: {temp_dir}")
    
    # Clean up previous results if requested
    if args.clean:
        print("=" * 50)
        print("Cleaning up previous beta estimate files...")
        print("=" * 50)
        old_files = list(args.output_dir.glob("beta_estimates_yeo7*.tsv"))
        for old_file in old_files:
            print(f"Removing: {old_file.name}")
            old_file.unlink()
        if old_files:
            print("Cleanup complete!")
        else:
            print("No previous beta estimate files found.")
        print()
    
    # ========================================================================
    # Find effect-size images
    # ========================================================================
    # Search for effect-size images with the contrast substring
    effect_size_files = list(args.bids_dir.glob(f"**/*effect-size*{args.contrast}*.nii.gz"))
    
    # Filter out masked versions if desired
    effect_size_files = [f for f in effect_size_files if 'masked' not in str(f).lower()]
    
    # Filter by participant and session if specified
    if participant_filter:
        effect_size_files = [f for f in effect_size_files 
                              if any(p in str(f) for p in participant_filter)]
    
    if session_filter:
        effect_size_files = [f for f in effect_size_files 
                              if any(s in str(f) for s in session_filter)]
    
    if len(effect_size_files) == 0:
        print("WARNING: No effect-size images found.")
        print(f"Searched for: *{args.contrast}*effect-size*.nii.gz")
        sys.exit(0)
    
    print("=" * 50)
    print("Yeo 7 Network Beta Extraction Script")
    print("=" * 50)
    print(f"BIDS Directory: {args.bids_dir}")
    print(f"Contrast substring: {args.contrast}")
    print(f"Effect-size filter: ENABLED (only files with 'effect-size' will be processed)")
    print(f"Mask type: Yeo 7-Network Parcellation")
    print(f"Output Directory: {args.output_dir}")
    print(f"Mock Mode: {'YES' if args.mock else 'NO'}")
    print(f"Save temps: {'YES (to ' + str(temp_dir) + ')' if args.scratch_temps else 'NO'}")
    print(f"Parallel cores: {args.ncores}")
    if participant_filter:
        print(f"Filtering participants: {', '.join(sorted(participant_filter))}")
    else:
        print("Processing all participants")
    if session_filter:
        print(f"Filtering sessions: {', '.join(sorted(session_filter))}")
    else:
        print("Processing all sessions")
    print("=" * 50)
    print(f"Found {len(effect_size_files)} effect-size images to process")
    print()
    
    # ========================================================================
    # Load Yeo 7 atlas and resample to first effect-size image space
    # ========================================================================
    print("=" * 50)
    print("ATLAS RESAMPLING")
    print("=" * 50)
    print("Loading Yeo 7 atlas...")
    atlas = fetch_atlas_yeo_2011()
    yeo_img = nib.load(atlas['thick_7'])
    print(f"Yeo atlas shape: {yeo_img.shape}")
    print(f"Networks found: {np.unique(yeo_img.get_fdata()[yeo_img.get_fdata() > 0])}")
    print()
    
    # Load first effect-size image as template for resampling
    print(f"Loading first effect-size image as template: {effect_size_files[0].name}")
    template_img = nib.load(str(effect_size_files[0]))
    print(f"Template shape: {template_img.shape}")
    print(f"Template voxel sizes: {np.diag(template_img.affine[:3, :3])}")
    print()
    
    # Resample Yeo atlas to template space (nearest neighbor to preserve labels)
    print("Resampling Yeo atlas to template image space...")
    yeo_resampled_img = nli.resample_to_img(yeo_img, template_img, interpolation='nearest')
    yeo_resampled_data = yeo_resampled_img.get_fdata()
    print(f"Resampled Yeo shape: {yeo_resampled_data.shape}")
    
    # Verify network labels are preserved
    original_networks = np.unique(yeo_img.get_fdata()[yeo_img.get_fdata() > 0])
    resampled_networks = np.unique(yeo_resampled_data[yeo_resampled_data > 0])
    print(f"Original networks: {original_networks}")
    print(f"Resampled networks: {resampled_networks}")
    
    if not np.array_equal(original_networks, resampled_networks):
        print("WARNING: Network labels may not be fully preserved after resampling!", file=sys.stderr)
    print()
    
    # Save resampled Yeo atlas as NIfTI file (one template for all participants)
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    yeo_resampled_nifti_file = args.output_dir / f"yeo_resampled_template_{timestamp}.nii.gz"
    nib.save(yeo_resampled_img, str(yeo_resampled_nifti_file))
    print(f"Saved resampled Yeo atlas template to: {yeo_resampled_nifti_file}")
    print()
    
    # Save resampled Yeo data to temporary numpy file for multiprocessing
    temp_yeo_data_file = Path(temp_dir or "/tmp") / f".yeo_resampled_{os.getpid()}.npy"
    np.save(temp_yeo_data_file, yeo_resampled_data)
    print(f"Saved resampled atlas to: {temp_yeo_data_file}")
    print("=" * 50)
    print()
    
    # ========================================================================
    # Process files in parallel
    # ========================================================================
    print("Processing effect-size images...")
    print()
    
    all_results = []
    
    if args.mock:
        # Mock mode: process sequentially without real computation
        for effect_size_file in sorted(effect_size_files):
            print(f"Processing: {effect_size_file.name}")
            rows = process_effect_size_file(effect_size_file, str(temp_yeo_data_file), 
                                           args.contrast, mock_mode=True)
            all_results.extend(rows)
    else:
        # Real mode: process in parallel
        with ProcessPoolExecutor(max_workers=args.ncores) as executor:
            futures = []
            for effect_size_file in sorted(effect_size_files):
                future = executor.submit(process_effect_size_file, effect_size_file, 
                                        str(temp_yeo_data_file), args.contrast, mock_mode=False)
                futures.append((effect_size_file, future))
            
            # Collect results as they complete
            for effect_size_file, future in futures:
                try:
                    rows = future.result()
                    print(f"Processed: {effect_size_file.name} -> {len(rows)} networks")
                    all_results.extend(rows)
                except Exception as e:
                    print(f"ERROR processing {effect_size_file.name}: {e}", file=sys.stderr)
    
    print()
    
    # ========================================================================
    # Save results to TSV
    # ========================================================================
    if all_results:
        df = pd.DataFrame(all_results)
        
        # Sort by participant, session, run, network
        df = df.sort_values(['participant_id', 'session', 'run', 'network_id']).reset_index(drop=True)
        
        # Generate output filename (use same timestamp as atlas)
        output_basename = f"beta_estimates_yeo7-7networks_{timestamp}.tsv"
        output_file = args.output_dir / output_basename
        
        # Save to TSV
        df.to_csv(output_file, sep='\t', index=False)
        
        print("=" * 50)
        print("Processing complete!")
        print("=" * 50)
        print(f"Results saved to: {output_file}")
        print(f"Total data rows: {len(df)}")
        print()
        print("First few rows:")
        print(df.head(10).to_string())
        print()
        print(f"Mask type: Yeo 7-Network Parcellation (resampled to template space)")
        print("=" * 50)
    else:
        print("No results to save - no valid data extracted")
    
    # Clean up temporary numpy files
    try:
        temp_yeo_data_file.unlink()
    except:
        pass


if __name__ == '__main__':
    main()
