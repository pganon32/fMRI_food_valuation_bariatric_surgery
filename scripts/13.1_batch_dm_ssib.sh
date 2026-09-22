#!/bin/bash
#SBATCH --job-name=dm_ssib_v
#SBATCH --output=dm_ssib_v_%j.out
#SBATCH --error=dm_ssib_v1_%j.err
#SBATCH --time=2:00:00                # Maximum runtime (adjust as needed)
#SBATCH --mem=16G                     # Memory allocation (adjust based on your needs)
#SBATCH --cpus-per-task=8              # Number of CPU cores (adjust as needed)
#SBATCH --account=def-amichaud      # Replace with your account name


# Load required modules
module load python

# activate VENV
source $HOME/nilearn_ENV_2020/bin/activate

# Run the dm script

python $HOME/projects/def-amichaud/share/GutBrain/scripts/scripts_design_matrix/13_dm_v7.py



