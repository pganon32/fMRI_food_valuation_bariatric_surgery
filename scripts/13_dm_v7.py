# This script processes fMRI data for a single subject and run, creating a design matrix and saving it along with relevant plots.


print('loading modules')

import sys
import matplotlib.pyplot as plt
import glob
import nibabel as nib
from nilearn import image
import numpy as np
from nilearn import plotting as plot
from nilearn.image.image import mean_img
import pandas as pd
from nilearn.image import load_img, new_img_like
from nilearn import image as img
from nilearn.glm.first_level import make_first_level_design_matrix
from nilearn.plotting import plot_design_matrix
import os
from nilearn.glm.first_level import FirstLevelModel
from nilearn.plotting import plot_stat_map
from nilearn.glm import threshold_stats_img
from nilearn.reporting import get_clusters_table
from nilearn.plotting import plot_roi
from nilearn.plotting import plot_contrast_matrix
from statsmodels.stats.outliers_influence import variance_inflation_factor
import statsmodels.api as sm


print('done loading modules')



# Comment below for use in batch processing
#subject_id = f"RND050"

project_dir = "/home/pagag24/projects/def-amichaud/share/GutBrain"
data_dir = f"{project_dir}/data2"
derivatives_dir = f"{project_dir}/derivatives4/fmriprep"
results_dir = f"{project_dir}/BIDS_results2"



hrf_model = "glover"
drift_model = "cosine"
t_r = 2.75


def process_single_subject_run(
    subject_id,
    ses_id,
    run_id,
    project_dir,
    data_dir,
    derivatives_dir,
    results_dir,
    drift_model,
    hrf_model,
    t_r,
    mvt_confounds_columns,
    suffix="",
    a_comp_cor=False,
    compute_vif=False,
    combine_by_food_category=True  # New parameter
):
    try:
        print(f"Processing subject: {subject_id}, session: {ses_id}, run: {run_id}")
        output_dir = os.path.join(results_dir, f"sub-{subject_id}/ses-{ses_id}/func")
        os.makedirs(output_dir, exist_ok=True)

        events_path = f"{data_dir}/sub-{subject_id}/ses-{ses_id}/func/sub-{subject_id}_ses-{ses_id}_task-BDM_run-{run_id}_events.tsv"
        run_imgs = f"{derivatives_dir}/sub-{subject_id}/ses-{ses_id}/func/sub-{subject_id}_ses-{ses_id}_task-BDM_run-{run_id}_space-MNI152NLin2009cAsym_desc-preproc_bold.nii.gz"
        mask_img = f"{derivatives_dir}/sub-{subject_id}/ses-{ses_id}/func/sub-{subject_id}_ses-{ses_id}_task-BDM_run-{run_id}_space-MNI152NLin2009cAsym_desc-brain_mask.nii.gz"
        confounds_path = f"{derivatives_dir}/sub-{subject_id}/ses-{ses_id}/func/sub-{subject_id}_ses-{ses_id}_task-BDM_run-{run_id}_desc-confounds_timeseries.tsv"

        print(f"Checking file paths...")
        if not os.path.exists(run_imgs):
            raise FileNotFoundError(f"BOLD image not found at {run_imgs}")
        if not os.path.exists(mask_img):
            raise FileNotFoundError(f"Mask image not found at {mask_img}")
        if not os.path.exists(confounds_path):
            raise FileNotFoundError(f"Confounds file not found at {confounds_path}")

        img_bold = nib.load(run_imgs)
        n_scans = img_bold.shape[3]
        print(f"Number of scans: {n_scans}")

        if os.path.exists(events_path):
            events = pd.read_csv(events_path, sep="\t")
            print(f"Loaded events from {events_path}")
        else:
            raise FileNotFoundError(f"No matching event files found at {events_path}")

        events.rename(columns={"value": "modulation"}, inplace=True)

        # # Comment this to remove mean centering of modulation
        events["modulation"] = events["modulation"] - events["modulation"].mean()
        print("mean-centered modulation")
        print(events["modulation"])

        confounds = pd.read_csv(confounds_path, sep="\t")
        print(f"Loaded confounds from {confounds_path}")

        if a_comp_cor:
            available_a_comp_cor_columns = [col for col in confounds.columns if "a_comp_cor_" in col]
            available_a_comp_cor_columns = available_a_comp_cor_columns[:10]
            filtered_mvt_confounds_columns = [col for col in mvt_confounds_columns if col not in ["csf", "white_matter"]]
            final_confounds_columns = list(dict.fromkeys(filtered_mvt_confounds_columns + available_a_comp_cor_columns))
        else:
            final_confounds_columns = mvt_confounds_columns

        final_confounds_columns = [col for col in final_confounds_columns if col in confounds.columns]
        print(f"Final confounds columns: {final_confounds_columns}")
        mvt_confounds = confounds[final_confounds_columns]

        frame_times = np.arange(n_scans) * t_r
        print(f"Frame times: {frame_times}")

        events_combined = pd.DataFrame()
        events_combined = events.copy()

        if combine_by_food_category:
            # Combine events: press_conf* -> press_conf, view_cross* -> view_cross, view* -> view, bid* -> bid
            events_combined['trial_type'] = events_combined['trial_type'].apply(
                lambda x: x.split('press_conf')[0] + 'press_conf' if x.startswith('press_conf') else (
                    x.split('view_cross')[0] + 'view_cross' if x.startswith('view_cross') else (
                        x.split('bid_conf')[0] + 'bid_conf' if x.startswith('bid_conf') else (
                            x.split('view')[0] + 'view' if x.startswith('view') else (
                                x.split('bid')[0] + 'bid' if x.startswith('bid') else x
                            )
                        )
                    )
                )
            )
        else:
            # Keep food categories: only combine press_conf* and view_cross*
            events_combined['trial_type'] = events_combined['trial_type'].apply(
                lambda x: x.split('press_conf')[0] + 'press_conf' if x.startswith('press_conf') else (
                    x.split('view_cross')[0] + 'view_cross' if x.startswith('view_cross') else x
                )
            )


        dm_pm_all = make_first_level_design_matrix(
            frame_times,
            events_combined,
            add_regs=mvt_confounds,
            add_reg_names=mvt_confounds.columns,
            drift_model=drift_model,
            hrf_model=hrf_model,
        )
        print(f"Design matrix created with columns: {dm_pm_all.columns.tolist()}")

        dm_pm_all.columns = [
            "mod_" + col if col in events_combined['trial_type'].unique() and col not in mvt_confounds.columns else col
            for col in dm_pm_all.columns
        ]



        if dm_pm_all.columns.duplicated().any():
            print(f"Duplicate columns found in design matrix: {dm_pm_all.columns[dm_pm_all.columns.duplicated()].tolist()}")


        events_all = events_combined.copy()
        events_all = events_all[['onset', 'duration', 'trial_type']]


        mod_cols = [col for col in dm_pm_all.columns if col.startswith("mod_")]
        print(f"Modulation columns: {mod_cols}")

        print(confounds.columns.tolist())

        dm_all = make_first_level_design_matrix(
            frame_times,
            events_all,
            add_regs=dm_pm_all[mod_cols + mvt_confounds.columns.tolist()],
            add_reg_names=mod_cols + mvt_confounds.columns.tolist()
        )

        if dm_all.columns.duplicated().any():
            duplicates = dm_all.columns[dm_all.columns.duplicated()].tolist()
            print(f"Duplicate columns found: {duplicates}")
            dm_all = dm_all.loc[:, ~dm_all.columns.duplicated()]

        columns_order = list(dict.fromkeys(
            [col for col in dm_all.columns if col.startswith('mod_view_bid_') or col.startswith('mod_') or col.startswith('view_') or col.startswith('bid_')]
            + [col for col in dm_all.columns if col not in mod_cols]
        ))
        dm_all = dm_all[columns_order]
        print(f"Final design matrix columns: {dm_all.columns.tolist()}")


        if combine_by_food_category:
            cols_to_remove = [
                col for col in dm_all.columns
                if (
                    col.startswith("press_conf") or
                    col.startswith("bid_conf") or
                    col.startswith("mod_press") or
                    col.startswith("mod_bid_conf") or
                    col.startswith("mod_bid")  or
                    col.startswith("mod_view_cross") or
                    col.startswith("view_cross")
                )
            ]
        else:
            # Keep food categories: remove generic view and mod_view, plus unwanted columns
            cols_to_remove = [
                col for col in dm_all.columns
                if (
                    col.startswith("press_conf") or
                    col.startswith("bid_conf") or
                    col.startswith("mod_press") or
                    col.startswith("mod_bid_conf") or
                    col.startswith("view_cross") or
                    col.startswith("mod_view_cross") or
                    col.startswith("mod_bid") or
                    col == "mod_view" or
                    col == "view"
                )
            ]
        print(f"Columns to remove: {cols_to_remove}")
        dm_all = dm_all.drop(columns=cols_to_remove)

        print("dm_all plot:")
        plot_design_matrix(dm_all)
        plt.show()

        if compute_vif:
            print("Computing VIF...")
            dm_for_vif = dm_all.copy()
            if "constant" in dm_for_vif.columns:
                vif_columns = [col for col in dm_for_vif.columns if col != "constant"]
            else:
                vif_columns = dm_for_vif.columns.tolist()

            vif_data = pd.DataFrame()
            vif_data["feature"] = vif_columns
            vif_data["VIF"] = [variance_inflation_factor(dm_for_vif[vif_columns].values, i) for i in range(len(vif_columns))]
            print(f"VIF data: {vif_data}")



        output_file = os.path.join(output_dir, f"sub-{subject_id}_ses-{ses_id}_run-{run_id}_dm_{suffix}.csv")
        dm_all.to_csv(output_file, index=False)
        print(f"Design matrix saved to {output_file}")

        # Save the design matrix plot as a PNG file
        output_png_path = os.path.join(output_dir, f"sub-{subject_id}_ses-{ses_id}_run-{run_id}_dm_{suffix}.png")
        fig, ax = plt.subplots(figsize=(12, 8))
        plot_design_matrix(dm_all, ax=ax)
        plt.savefig(output_png_path, dpi=300)
        plt.close(fig)
        print(f"Design matrix plot saved to {output_png_path}")

    except Exception as e:
        print(f"Error processing sub-{subject_id}, ses-{ses_id}, run-{run_id}: {e}")




# Load the list of runs to exclude based on tsnr_fd_outliers.txt
exclude_file = os.path.join(derivatives_dir, "tsnr_fd_outliers.txt")
if os.path.exists(exclude_file):
    with open(exclude_file, "r") as f:
        excluded_runs = [line.strip() for line in f.readlines()]
    print(f"Excluded runs: {excluded_runs}")
else:
    excluded_runs = []
    print("No exclusion file found. Proceeding with all runs.")

# Loop through all participants in the derivatives directory
participants = [
    d for d in os.listdir(derivatives_dir)
    if os.path.isdir(os.path.join(derivatives_dir, d)) and d.startswith("sub-")
]
#participants = ["sub-RND050"] # For testing, you can specify a single subject

for participant in participants:
    subject_id = participant.split("-")[1]
    for ses_id in ["1", "2", "3", "4"]:
        for run_id in ["1", "2", "3"]:
            run_identifier = f"sub-{subject_id}_ses-{ses_id}_task-BDM_run-{run_id}_bold"
            if run_identifier in excluded_runs:
                print(f"Skipping excluded run: {run_identifier}")
                continue
            try:
                process_single_subject_run(
                    subject_id=subject_id,
                    ses_id=ses_id,
                    run_id=run_id,
                    project_dir=project_dir,
                    data_dir=data_dir,
                    derivatives_dir=derivatives_dir,
                    results_dir=results_dir,
                    drift_model=drift_model,
                    hrf_model=hrf_model,
                    t_r=t_r,
                    mvt_confounds_columns=["trans_x", "trans_y", "trans_z", "rot_x", "rot_y", "rot_z", "csf", "white_matter"],
                    suffix=f"v7_literature_complex",
                    a_comp_cor=False,
                    compute_vif=True,
                    combine_by_food_category=False
                )
            except Exception as e:
                print(f"Failed for sub-{subject_id}, ses-{ses_id}, run-{run_id}: {e}")
