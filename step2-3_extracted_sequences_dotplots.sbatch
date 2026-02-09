#!/bin/bash
#SBATCH --job-name=extracted_seq_dotplots
#SBATCH --output=extracted_seq_dotplots_%A_%a.out
#SBATCH --error=extracted_seq_dotplots_%A_%a.err
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=8:00:00
#SBATCH --array=1-6

# Load helper script
source ./step2-3_helper-script.sh

# Load necessary modules
load_modules

# Set base directories and reference genome
REFERENCE="/ibex/project/c2303/20250413_Redo-C-merolae-analysis/step2_minimap2-align-all-reads-and-contigs-to-CmerT2T-genome/DATA/REFERENCE-GENOME/c-merolae-10d/GCF_000091205.1_ASM9120v1_genomic.fna"
EXTRACTED_SEQ_DIR="20250901_map-extracted-sequences-to-ref"
OUTPUT_DIR="EXTRACTED_SEQUENCES_DOTPLOTS"

# Create output directory
mkdir -p ${OUTPUT_DIR}

# Get the list of all_*.fasta files and store in an array
mapfile -t FASTA_FILES < <(find "${EXTRACTED_SEQ_DIR}" -name "all_*.fasta" | sort)

# Get the current FASTA file based on array index (SLURM_ARRAY_TASK_ID is 1-based)
CURRENT_INDEX=$((SLURM_ARRAY_TASK_ID - 1))
FASTA_FILE="${FASTA_FILES[$CURRENT_INDEX]}"

# Extract information from the file path
file_info=$(extract_file_info "$FASTA_FILE")
IFS='|' read -r SAMPLE_NAME HIT_TYPE FASTA_BASENAME MARKER_TYPE <<< "$file_info"

log_info "Job array ID: ${SLURM_ARRAY_TASK_ID}"
log_info "Processing FASTA file: ${FASTA_FILE}"
log_info "Sample: ${SAMPLE_NAME}"
log_info "Hit type: ${HIT_TYPE}"
log_info "FASTA basename: ${FASTA_BASENAME}"
log_info "Marker type: ${MARKER_TYPE}"

# Generate dotplot using helper function
OUTPUT_PREFIX="${SAMPLE_NAME}_${MARKER_TYPE}_${HIT_TYPE}_${FASTA_BASENAME}_vs_reference"
generate_dotplot "$FASTA_FILE" "$REFERENCE" "$OUTPUT_DIR" "$OUTPUT_PREFIX"

log_success "Job ${SLURM_ARRAY_TASK_ID} completed for ${FASTA_BASENAME}"
log_info "Dotplot generated: ${OUTPUT_DIR}/${OUTPUT_PREFIX}.pdf"
