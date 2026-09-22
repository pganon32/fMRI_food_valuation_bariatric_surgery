# Process specific participants AND specific sessions
bash v4_extract_beta.sh \
  --bids-dir ~/projects/def-amichaud/share/GutBrain/BIDS_results2/ \
  --contrast "mod_hi_vs_mod_lo_v7_literature_complex_psc" \
  --output-dir ~/projects/def-amichaud/share/GutBrain/BIDS_results2/3dLmer/results/mod_hi_vs_mod_lo_v7_literature_complex_psc_qc_final \
  --scratch-temps \
  --ncores 0 \
  --cluster "/home/pagag24/projects/def-amichaud/share/GutBrain/BIDS_results2/3dLmer/results/mod_hi_vs_mod_lo_v7_literature_complex_psc_qc_final/sess2vs1_clustered_p001_ACF_residuals_mod_hi_vs_mod_lo_v7_literature_complex_psc_qc_final.nii.gz" \
  --clean
  # Use --mock to test without processing
