#!/bin/bash
#SBATCH --job-name=blast_search_array_codA_plasmid_portion
#SBATCH --output=blast_search_array_codA_plasmid_portion_%A_%a.out
#SBATCH --error=blast_search_array_codA_plasmid_portion_%A_%a.err
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=4:00:00
#SBATCH --array=1-12

# Load necessary modules (adjust as needed for your system)
module load blast

# Set base directories
BLASTDB_BASE_DIR="BLAST_DATABASES"
BLAST_RESULTS_DIR="BLAST_RESULTS"
# QUERY_SEQUENCE="/ibex/scratch/projects/c2303/20250831_blast_for_rabeaa/BLAST_QUERIES/mVenus-plasmid-portion.fa" 
QUERY_SEQUENCE="/ibex/scratch/projects/c2303/20250831_blast_for_rabeaa/BLAST_QUERIES/codA-plasmid-portion.fa" 

# BLAST parameters - adjust as needed
EVALUE="1e-5"
MAX_TARGET_SEQS="10"
OUTFMT="6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore"

# Create main BLAST results output directory
mkdir -p ${BLAST_RESULTS_DIR}

# Check if query sequence exists
if [ ! -f "${QUERY_SEQUENCE}" ]; then
    echo "ERROR: Query sequence file not found: ${QUERY_SEQUENCE}"
    exit 1
fi

# Get the list of sample directories and store in an array
mapfile -t SAMPLE_DIRS < <(find "${BLASTDB_BASE_DIR}" -maxdepth 1 -type d -name "*" | grep -v "^${BLASTDB_BASE_DIR}$" | sort)

# Get the current directory based on array index (SLURM_ARRAY_TASK_ID is 1-based)
CURRENT_INDEX=$((SLURM_ARRAY_TASK_ID - 1))
SAMPLE_DIR="${SAMPLE_DIRS[$CURRENT_INDEX]}"

# Extract sample name from the directory path
SAMPLE_NAME=$(basename "$SAMPLE_DIR")
RESULTS_DIR="${BLAST_RESULTS_DIR}/${SAMPLE_NAME}"

echo "Job array ID: ${SLURM_ARRAY_TASK_ID}"
echo "Processing sample: ${SAMPLE_NAME}"
echo "BLAST DB directory: ${SAMPLE_DIR}"
echo "Results output directory: ${RESULTS_DIR}"
echo "Query sequence: ${QUERY_SEQUENCE}"

# Create output directory for this sample's BLAST results
mkdir -p "${RESULTS_DIR}"

# Function to run BLAST and check results
run_blast() {
    local db_path=$1
    local db_name=$2
    local output_file=$3
    
    echo "Running BLAST against ${db_name} database..."
    blastn -query "${QUERY_SEQUENCE}" \
           -db "${db_path}" \
           -out "${output_file}" \
           -evalue ${EVALUE} \
           -max_target_seqs ${MAX_TARGET_SEQS} \
           -outfmt "${OUTFMT}" \
           -num_threads ${SLURM_CPUS_PER_TASK}
    
    if [ $? -eq 0 ]; then
        echo "BLAST completed successfully for ${db_name}"
        
        # Check if results were found
        if [ -s "${output_file}" ]; then
            echo "BLAST hits found for ${db_name}"
            echo "Number of hits: $(wc -l < "${output_file}")"
        else
            echo "No BLAST hits found for ${db_name}"
        fi
    else
        echo "ERROR: BLAST failed for ${db_name}"
        return 1
    fi
}

# BLAST against primary contigs database
PRIMARY_DB="${SAMPLE_DIR}/${SAMPLE_NAME}_primary"
if [ -f "${PRIMARY_DB}.nhr" ]; then
    PRIMARY_OUTPUT="${RESULTS_DIR}/${SAMPLE_NAME}_primary_blast_results.txt"
    run_blast "${PRIMARY_DB}" "primary contigs" "${PRIMARY_OUTPUT}"
else
    echo "WARNING: Primary contigs database not found: ${PRIMARY_DB}"
fi

# BLAST against alternate contigs database
ALTERNATE_DB="${SAMPLE_DIR}/${SAMPLE_NAME}_alternate"
if [ -f "${ALTERNATE_DB}.nhr" ]; then
    ALTERNATE_OUTPUT="${RESULTS_DIR}/${SAMPLE_NAME}_alternate_blast_results.txt"
    run_blast "${ALTERNATE_DB}" "alternate contigs" "${ALTERNATE_OUTPUT}"
else
    echo "WARNING: Alternate contigs database not found: ${ALTERNATE_DB}"
fi

# BLAST against combined database
COMBINED_DB="${SAMPLE_DIR}/${SAMPLE_NAME}_combined"
if [ -f "${COMBINED_DB}.nhr" ]; then
    COMBINED_OUTPUT="${RESULTS_DIR}/${SAMPLE_NAME}_combined_blast_results.txt"
    run_blast "${COMBINED_DB}" "combined contigs" "${COMBINED_OUTPUT}"
else
    echo "WARNING: Combined database not found: ${COMBINED_DB}"
fi

# Create a summary file for this sample
SUMMARY_FILE="${RESULTS_DIR}/${SAMPLE_NAME}_blast_summary.txt"
echo "BLAST Summary for Sample: ${SAMPLE_NAME}" > "${SUMMARY_FILE}"
echo "Query sequence: ${QUERY_SEQUENCE}" >> "${SUMMARY_FILE}"
echo "Date: $(date)" >> "${SUMMARY_FILE}"
echo "Parameters used:" >> "${SUMMARY_FILE}"
echo "  E-value: ${EVALUE}" >> "${SUMMARY_FILE}"
echo "  Max target sequences: ${MAX_TARGET_SEQS}" >> "${SUMMARY_FILE}"
echo "  Output format: ${OUTFMT}" >> "${SUMMARY_FILE}"
echo "" >> "${SUMMARY_FILE}"

# Add hit counts to summary
for result_file in "${RESULTS_DIR}"/*_blast_results.txt; do
    if [ -f "${result_file}" ]; then
        db_type=$(basename "${result_file}" | sed 's/.*_\([^_]*\)_blast_results.txt/\1/')
        hit_count=$(wc -l < "${result_file}")
        echo "${db_type} database: ${hit_count} hits" >> "${SUMMARY_FILE}"
    fi
done

echo "BLAST search completed for sample ${SAMPLE_NAME}"
echo "Results saved in: ${RESULTS_DIR}"
echo "Job ${SLURM_ARRAY_TASK_ID} completed for sample ${SAMPLE_NAME}"