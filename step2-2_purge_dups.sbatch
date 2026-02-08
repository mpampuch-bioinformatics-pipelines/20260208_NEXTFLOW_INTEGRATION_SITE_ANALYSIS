#!/bin/bash
#SBATCH --job-name=purge_dups_array
#SBATCH --output=purge_dups_%A_%a.out
#SBATCH --error=purge_dups_%A_%a.err
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --time=24:00:00
#SBATCH --array=1-12

# Load helper script
source ./step2-2_helper-script.sh

# Load necessary modules
load_modules

# Set base directories
ASSEMBLIES_DIR="ASSEMBLIES"
PURGED_ASSEMBLIES_DIR="PURGED_ASSEMBLIES"
DATA_DIR="DATA"

# Create output directory
mkdir -p ${PURGED_ASSEMBLIES_DIR}

# Get the list of assembly directories and store in an array
mapfile -t ASSEMBLY_DIRS < <(find "${ASSEMBLIES_DIR}" -maxdepth 1 -type d -name "*_C_merolae10D" | sort)

# Get the current assembly based on array index (SLURM_ARRAY_TASK_ID is 1-based)
CURRENT_INDEX=$((SLURM_ARRAY_TASK_ID - 1))
ASSEMBLY_DIR="${ASSEMBLY_DIRS[$CURRENT_INDEX]}"
SAMPLE_NAME=$(basename "$ASSEMBLY_DIR")

echo "Job array ID: ${SLURM_ARRAY_TASK_ID}"
echo "Processing sample: ${SAMPLE_NAME}"
echo "Assembly directory: ${ASSEMBLY_DIR}"

# Define input and output files
PRIMARY_CONTIGS="${ASSEMBLY_DIR}/${SAMPLE_NAME}.p_ctg.fa"
ALTERNATE_CONTIGS="${ASSEMBLY_DIR}/${SAMPLE_NAME}.a_ctg.fa"
OUTPUT_DIR="${PURGED_ASSEMBLIES_DIR}/${SAMPLE_NAME}"

# Create output directory for this sample
mkdir -p "${OUTPUT_DIR}"

# Check if primary contigs file exists
if [ ! -f "$PRIMARY_CONTIGS" ]; then
    echo "ERROR: Primary contigs file ${PRIMARY_CONTIGS} not found"
    exit 1
fi

echo "Primary contigs file: ${PRIMARY_CONTIGS}"
echo "Output directory: ${OUTPUT_DIR}"

# Function to find PacBio reads for the sample
find_pacbio_reads() {
    local sample_id=$(echo "$SAMPLE_NAME" | cut -d'_' -f1)
    local reads_file="${DATA_DIR}/${sample_id}.fastq"
    
    if [ -f "$reads_file" ]; then
        echo "$reads_file"
    else
        log_error "PacBio reads file ${reads_file} not found"
        return 1
    fi
}

# Main execution
log_info "Starting purge_dups processing for ${SAMPLE_NAME}..."

# Find PacBio reads
PACBIO_READS=$(find_pacbio_reads)
if [ $? -ne 0 ]; then
    log_error "Could not find PacBio reads for ${SAMPLE_NAME}"
    exit 1
fi

log_info "PacBio reads file: ${PACBIO_READS}"

# Run purge_dups on primary contigs
log_info "Processing primary contigs..."
run_purge_dups_pipeline "$PRIMARY_CONTIGS" "$PACBIO_READS" "${OUTPUT_DIR}/primary" "${SAMPLE_NAME}_primary" "8G"

# Run purge_dups on alternate contigs if they exist
if [ -f "$ALTERNATE_CONTIGS" ]; then
    log_info "Processing alternate contigs..."
    run_purge_dups_pipeline "$ALTERNATE_CONTIGS" "$PACBIO_READS" "${OUTPUT_DIR}/alternate" "${SAMPLE_NAME}_alternate" "8G"
else
    log_warning "No alternate contigs found for ${SAMPLE_NAME}"
fi

log_success "Job ${SLURM_ARRAY_TASK_ID} completed for sample ${SAMPLE_NAME}"
log_info "Results saved in: ${OUTPUT_DIR}"
