#!/bin/bash
#SBATCH --qos=short
#SBATCH --mem=60000
#SBATCH --cpus=16
#SBATCH --job-name=DeMo_ensemble
#SBATCH --account=compacts
#SBATCH --output=log/%j.out
#SBATCH --error=log/%j.err
#SBATCH --workdir=/home/damianho/projects/social_agent_based_modelling/
#SBATCH --time=0-05:00:00

module load julia/1.6.1
simulation='scripts/run.jl'

for s in {110..129}
do
    srun julia $simulation $s
done
