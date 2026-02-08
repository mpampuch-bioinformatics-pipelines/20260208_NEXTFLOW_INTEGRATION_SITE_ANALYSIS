#!/bin/bash
#SBATCH --job-name=hifiasm_array
#SBATCH --output=hifiasm_array_%A_%a.out
#SBATCH --error=hifiasm_array_%A_%a.err
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=128G
#SBATCH --time=24:00:00
#SBATCH --array=1-12

# Load necessary modules (adjust as needed for your system)
module load hifiasm

# Set base directories
DATA_DIR="/ibex/scratch/projects/c2303/20250831_blast_for_rabeaa/DATA"
OUTPUT_BASE_DIR="ASSEMBLIES"

# Create main output directory
mkdir -p ${OUTPUT_BASE_DIR}

# Get the list of fastq files and store in an array
mapfile -t FASTQ_FILES < <(find "${DATA_DIR}" -name "*.fastq" | sort)

# Get the current file based on array index (SLURM_ARRAY_TASK_ID is 1-based)
CURRENT_INDEX=$((SLURM_ARRAY_TASK_ID - 1))
FASTQ_FILE="${FASTQ_FILES[$CURRENT_INDEX]}"

# Extract sample name from the fastq file path
SAMPLE_NAME=$(basename "$FASTQ_FILE" .fastq)
OUTPUT_DIR="${OUTPUT_BASE_DIR}/${SAMPLE_NAME}"

echo "Job array ID: ${SLURM_ARRAY_TASK_ID}"
echo "Processing sample: ${SAMPLE_NAME}"
echo "Input file: ${FASTQ_FILE}"
echo "Output directory: ${OUTPUT_DIR}"

# Create output directory for this sample
mkdir -p "${OUTPUT_DIR}"

# Run HiFiASM
echo "Starting HiFiASM assembly for ${SAMPLE_NAME}..."
hifiasm -o "${OUTPUT_DIR}/${SAMPLE_NAME}" -t 32 --primary "${FASTQ_FILE}"

# Check if assembly was successful
if [ $? -eq 0 ]; then
    echo "HiFiASM completed successfully for ${SAMPLE_NAME}"
    
    # Convert the GFA output to FASTA (optional)
    if [ -f "${OUTPUT_DIR}/${SAMPLE_NAME}.p_ctg.gfa" ]; then
        echo "Converting primary contigs to FASTA..."
        awk '/^S/{print ">"$2"\n"$3}' "${OUTPUT_DIR}/${SAMPLE_NAME}.p_ctg.gfa" > "${OUTPUT_DIR}/${SAMPLE_NAME}.p_ctg.fa"
    fi
    
    if [ -f "${OUTPUT_DIR}/${SAMPLE_NAME}.a_ctg.gfa" ]; then
        echo "Converting alternate contigs to FASTA..."
        awk '/^S/{print ">"$2"\n"$3}' "${OUTPUT_DIR}/${SAMPLE_NAME}.a_ctg.gfa" > "${OUTPUT_DIR}/${SAMPLE_NAME}.a_ctg.fa"
    fi
    
    echo "Sample ${SAMPLE_NAME} processing completed successfully"
else
    echo "ERROR: HiFiASM failed for sample ${SAMPLE_NAME}"
    exit 1
fi

echo "Job ${SLURM_ARRAY_TASK_ID} completed for sample ${SAMPLE_NAME}"
