# fMRI_food_valuation_bariatric_surgery

## Project Overview

This repository is for better understanding and reproducibility fo our paper titled neural correlates of subjective food valuation in the context of bariatric surgery. The pipeline is tailored for data acquired on Philips scanners and designed for use on Alliance Canada clusters.

> **Note:** The scripts may require adaptation for other datasets or environments due to hard-coded filename and directory patterns. Future patches may improve portability. Scripts are labeled with a 2 digits prefix, indicating the order in which they should be run. 
---

## Table of Contents

- [Prerequisites](#prerequisites)
- [Data Structure](#data-structure)
- [Workflow](#workflow)
  - [1. DICOM to NIfTI Conversion](#1-dicom-to-nifti-conversion)
  - [2. Organize Data in BIDS Format](#2-organize-data-in-bids-format)
  - [3. Add Metadata Fields](#3-add-metadata-fields)
  - [4. Quality Control](#4-quality-control)
  - [5. Preprocessing](#5-preprocessing)
  - [6. Event File Creation](#6-event-file-creation)
  - [7. Design Matrix Construction](#7-design-matrix-construction)
  - [8. First-Level Modeling](#8-first-level-modeling)
  - [9. ROI Mask Generation](#9-roi-mask-generation)
  - [10. ROI Z-Score Calculation](#10-roi-z-score-calculation)
  - [11. ROI Statistical Analysis](#11-roi-statistical-analysis)
- [Troubleshooting](#troubleshooting)
- [References](#references)
- [Contributing and Citation](#contributing-and-citation)

---

## Prerequisites

- **Cluster access:** Slurm-enabled HPC cluster (e.g., Alliance Canada or equivalent)
- **Software:**
  - Bash
  - Python 3.x
  - Apptainer / Singularity
  - dcm2niix
  - fMRIPrep
  - MRIQC
  - Nilearn
  - AFNI
  - R
- **Container images / modules:**
  - MRIQC container image
  - fMRIPrep container or module
  - AFNI module on the cluster
- **Data:**
  - Philips scanner DICOMs organized in a BIDS-style directory structure
  - Raw data under a `sourcedata` / `DICOM` layout before conversion to NIfTI
  - Subject/session folders such as `sub-<ID>/ses-<number>/...`

---

## Data Structure

```
/data/
└── sourcedata/
    └── {participant-id}/
        └── DICOM/
            └── {BL,4M,12M,24M}/
```

**Event files must have columns:**  
`Picture | Stimulus | Start Time | Bid Start Time | Bid Duration | Price`

---

## Workflow

### 1. Scripts for behavioral analysis

In order, run scripts 0 to 11. This will produce figure 2 as well as S2-14. Input data is a mix of redcap raw data CSVs as well as E-prime WTP files. 
This script is also required for the R code to produce tables s2-s4 :
```bash
part_r2_analysis_func.R
```

---

### 2. Event File Creation

```bash
python 12_create_evs.py
```

---

### 3. Design Matrix Construction

```bash
python 13_dm_v7.py
# Adjust suffix and columns as needed
```

Reference:  
Abraham A et al. (2014), Front Neuroinform.

---

### 4. DICOM to NIfTI Conversion

```bash
bash 14_raw_dcm_to_nii_v5.sh
# Adjust participant label prefix if needed
```

Reference:  
Li X et al. (2016), J Neurosci Methods.

---

### 5. Organize Data in BIDS Format

```bash
bash 15_rename_BIDS_mv.sh
# Adjust Bo and fieldmaps names based on acquisition time
```

Reference:  
Gorgolewski, K.J. et al. (2016), Scientific Data.

---

### 6. Add Metadata Fields

```bash
bash 16_slice_info_json_v4.sh
bash 17_add_int_for_fmap.sh
# Add "IntendedFor" and slice acquisition info to .json files
```
*Philips DICOM headers may lack info; consult with MR specialist as needed.*

---

### 7. Quality Control

Build MRIQC image:
```bash
apptainer build mriqc-24.0.2.sif docker://nipreps/mriqc:24.0.2
```

Run:
```bash
18_mriqc_v3.sh # create this script first
bash 19_batch_mriqc_v3.sh # run it on all participants
bash 20_mriqc_group_v2.sh # create the group report
```


### 8. Preprocessing

Run fMRIPrep:
```bash
21_v5_fmriprep.sh
22_batch_fmriprep.sh
# Adjust options, time, hardware requirements as needed
```

*Run it with exclusion list file from QC process as needed:*
```
sub-{ID}_ses-{ID}_task-BDM_run-{ID}_bold
```

Reference:  
Esteban O et al. (2017), PLoS ONE.

---

Reference:  
Esteban O et al. (2019), Nat Methods.

---

### 9. Create mask files for Quality control vmPFC coverage

```bash
23_create_brain_masks.ipynb
24_v2_mask_intersection_alliance.sh
25_merge_coverage_mriqc_v2.ipynb # adds vmPFC coverage to QC summary data file
```

Reference:  
Newton Fenner et al. (2023), PLoS ONE.

---

### 10. Set up final list of participants (after final QC)

```bash
26_create_participant_tsv_json.ipynb
27_create_afni_datatable_qc_final.ipynb
```



### 11. First-Level Modeling

```bash
python 28_first_level_glm_combined_runs_v7.py
# Adjust contrast and settings as needed
```

---
### 11. Second level model cluster generation for Model 1

```bash
bash 29_working_3dLMEr_longitudinal_v8.sh
bash 30_3dFWHMx_ClustSim_from_res_v6.sh
bash 31_3dclusterize_v13.sh
bash 32_effect_maps_afni_to_nifti_v4.sh
33_run_whereami_analysis.sh # this script must be written before running batch process
bash 34_batch_whereami_analysis_v4_no_twl.sh

```

### 12. Second level model cluster generation for Model 2

```bash
bash 35_working_3dLMEr_longitudinal_v10_twl.sh
bash 30_3dFWHMx_ClustSim_from_res_v6.sh
bash 36_3dclusterize_v14_twl.sh
bash 37_effect_maps_afni_to_nifti_v5_twl.sh
bash 38_batch_whereami_analysis_v5_twl.sh

```

### 13. Create results table (table 1 and table s1)

```bash
39_cluster_table_qc_final.ipynb
```

### 14. Extract parameter estimates per cluster or Yeo parcellation for fig. 3 and 4.

```bash
40_v4_extract_beta.sh
41_execute_extract_beta.sh
42_v2_yeo_parsing.ipynb
43_execute_yeo_parsing.sh
```

### 15. Create glassbrain figures

```bash
45_fmri_article_figures_v2.ipynb
```

### 16 Create parameter estimate plots for figure 6 (Model 2)

```bash
# reuse those scripts with the appropriate clusters:
40_v4_extract_beta.sh
41_execute_extract_beta.sh
# run the following script to plot parameter estimates as a function of Total weight loss
46_fig_6_twl_beta_plots.ipynb
```

## Troubleshooting

- **Directory or filename errors:** Ensure strict compliance with required folder structure and naming conventions.
- **Missing DICOM header info:** Consult with MR specialist, especially for Philips scanners.
- **MRIQC/fMRIPrep container fails:** Check container build versions and cluster compatibility.
- **Script errors:** Read script comments for adjustable parameters.

---

## References

- Gorgolewski, K.J., Auer, T., Calhoun, V.D., Craddock, R.C., Das, S., Duff, E.P., Flandin, G., Ghosh, S.S., Glatard, T., Halchenko, Y.O., Handwerker, D.A., Hanke, M., Keator, D., Li, X., Michael, Z., Maumet, C., Nichols, B.N., Nichols, T.E., Pellman, J., Poline, J.-B., Rokem, A., Schaefer, G., Sochat, V., Triplett, W., Turner, J.A., Varoquaux, G., Poldrack, R.A. (2016). The brain imaging data structure, a format for organizing and describing outputs of neuroimaging experiments. Scientific Data, 3 (160044). doi:10.1038/sdata.2016.44
- Li X, Morgan PS, Ashburner J, Smith J, Rorden C. (2016) J Neurosci Methods. 264:47-56.
- Esteban O et al. (2017) PLoS ONE 12(9): e0184661.
- Esteban O et al. (2019) Nat Methods 16, 111–116.
- Abraham A et al. (2014) Front Neuroinform. 8:14.
- Newton-Fenner A et al. (2023) [Economic value in the Brain: A meta-analysis...](https://doi.org/10.1177/20438087231160434)

---

## Contributing and Citation

Contributions welcome! Please open issues or pull requests.

If you use these scripts, please cite the relevant references above.

---
