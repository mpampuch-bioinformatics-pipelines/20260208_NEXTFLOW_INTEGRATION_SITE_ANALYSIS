#!/bin/bash
#SBATCH --job-name=extract_blast_hits
#SBATCH --output=extract_blast_hits_%A_%a.out
#SBATCH --error=extract_blast_hits_%A_%a.err
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=2:00:00
#SBATCH --array=1-12

# Load necessary modules
module load blast

# Set base directories
BLAST_RESULTS_DIR="BLAST_RESULTS"
EXTRACTED_SEQUENCES_DIR="EXTRACTED_SEQUENCES"
BLASTDB_BASE_DIR="BLAST_DATABASES"

# Flanking region size (bp)
# FLANK_SIZE=8000 # Original Analysis
FLANK_SIZE=50000 # New Analysis

# Create main output directory
mkdir -p ${EXTRACTED_SEQUENCES_DIR}

# Get the list of sample directories and store in an array
mapfile -t SAMPLE_DIRS < <(find "${BLAST_RESULTS_DIR}" -maxdepth 1 -type d -name "*" | grep -v "^${BLAST_RESULTS_DIR}$" | sort)

# Get the current directory based on array index
CURRENT_INDEX=$((SLURM_ARRAY_TASK_ID - 1))
SAMPLE_DIR="${SAMPLE_DIRS[$CURRENT_INDEX]}"

# Extract sample name
SAMPLE_NAME=$(basename "$SAMPLE_DIR")
OUTPUT_DIR="${EXTRACTED_SEQUENCES_DIR}/${SAMPLE_NAME}"
DB_DIR="${BLASTDB_BASE_DIR}/${SAMPLE_NAME}"

echo "Job array ID: ${SLURM_ARRAY_TASK_ID}"
echo "Processing sample: ${SAMPLE_NAME}"
echo "BLAST results directory: ${SAMPLE_DIR}"
echo "Output directory: ${OUTPUT_DIR}"
echo "Flanking region size: ${FLANK_SIZE} bp"

# Create output directory for this sample
mkdir -p "${OUTPUT_DIR}"

# Function to extract sequences from BLAST results
extract_sequences() {
    local blast_results_file=$1
    local database_path=$2
    local db_type=$3
    local output_subdir=$4
    
    echo "Processing ${db_type} BLAST results..."
    
    if [ ! -f "${blast_results_file}" ]; then
        echo "WARNING: BLAST results file not found: ${blast_results_file}"
        return 1
    fi
    
    if [ ! -s "${blast_results_file}" ]; then
        echo "WARNING: BLAST results file is empty: ${blast_results_file}"
        return 1
    fi
    
    if [ ! -f "${database_path}.nhr" ]; then
        echo "WARNING: Database not found: ${database_path}"
        return 1
    fi
    
    # Create subdirectory for this database type
    mkdir -p "${output_subdir}"
    
    # Counter for hit numbering
    hit_counter=1
    
    # Read BLAST results line by line
    while IFS=$'\t' read -r qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore; do
        # Skip empty lines
        [ -z "$qseqid" ] && continue
        
        echo "Processing hit ${hit_counter}: ${sseqid} (${sstart}-${send})"
        
        # Calculate flanking regions
        # Note: sstart and send might be reversed for minus strand hits
        if [ "$sstart" -le "$send" ]; then
            # Plus strand
            hit_start=$sstart
            hit_end=$send
            strand="plus"
        else
            # Minus strand
            hit_start=$send
            hit_end=$sstart
            strand="minus"
        fi
        
        # Calculate extraction coordinates with flanking regions
        extract_start=$((hit_start - FLANK_SIZE))
        extract_end=$((hit_end + FLANK_SIZE))
        
        # Ensure coordinates are not negative
        if [ "$extract_start" -lt 1 ]; then
            extract_start=1
        fi
        
        # Create output filename
        output_file="${output_subdir}/${SAMPLE_NAME}_${db_type}_hit${hit_counter}_${sseqid}_${hit_start}-${hit_end}_flanked.fasta"
        
        # Extract sequence using blastdbcmd
        blastdbcmd -db "${database_path}" \
                   -entry "${sseqid}" \
                   -range "${extract_start}-${extract_end}" \
                   -out "${output_file}" \
                   -outfmt "%f"
        
        if [ $? -eq 0 ] && [ -s "${output_file}" ]; then
            # Modify the FASTA header to include hit information
            temp_file="${output_file}.tmp"
            sed "1s/.*/>hit${hit_counter}_${sseqid}_${hit_start}-${hit_end}_flanked_${extract_start}-${extract_end}_${strand}_evalue:${evalue}_identity:${pident}%/" "${output_file}" > "${temp_file}"
            mv "${temp_file}" "${output_file}"
            
            echo "  Successfully extracted sequence to: $(basename "${output_file}")"
        else
            echo "  ERROR: Failed to extract sequence for hit ${hit_counter}"
            # Remove empty file if it exists
            [ -f "${output_file}" ] && rm "${output_file}"
        fi
        
        ((hit_counter++))
        
    done < "${blast_results_file}"
    
    echo "Processed $((hit_counter - 1)) hits for ${db_type} database"
}

# Process each database type
echo "Starting sequence extraction for sample: ${SAMPLE_NAME}"

# Extract from primary contigs database
PRIMARY_RESULTS="${SAMPLE_DIR}/${SAMPLE_NAME}_primary_blast_results.txt"
PRIMARY_DB="${DB_DIR}/${SAMPLE_NAME}_primary"
PRIMARY_OUTPUT="${OUTPUT_DIR}/primary_hits"
extract_sequences "${PRIMARY_RESULTS}" "${PRIMARY_DB}" "primary" "${PRIMARY_OUTPUT}"

# Extract from alternate contigs database
ALTERNATE_RESULTS="${SAMPLE_DIR}/${SAMPLE_NAME}_alternate_blast_results.txt"
ALTERNATE_DB="${DB_DIR}/${SAMPLE_NAME}_alternate"
ALTERNATE_OUTPUT="${OUTPUT_DIR}/alternate_hits"
extract_sequences "${ALTERNATE_RESULTS}" "${ALTERNATE_DB}" "alternate" "${ALTERNATE_OUTPUT}"

# Extract from combined database
COMBINED_RESULTS="${SAMPLE_DIR}/${SAMPLE_NAME}_combined_blast_results.txt"
COMBINED_DB="${DB_DIR}/${SAMPLE_NAME}_combined"
COMBINED_OUTPUT="${OUTPUT_DIR}/combined_hits"
extract_sequences "${COMBINED_RESULTS}" "${COMBINED_DB}" "combined" "${COMBINED_OUTPUT}"

# Create a summary file for this sample
SUMMARY_FILE="${OUTPUT_DIR}/${SAMPLE_NAME}_extraction_summary.txt"
echo "Sequence Extraction Summary for Sample: ${SAMPLE_NAME}" > "${SUMMARY_FILE}"
echo "Date: $(date)" >> "${SUMMARY_FILE}"
echo "Flanking region size: ${FLANK_SIZE} bp upstream and downstream" >> "${SUMMARY_FILE}"
echo "" >> "${SUMMARY_FILE}"

# Count extracted sequences for each database type
for subdir in primary_hits alternate_hits combined_hits; do
    if [ -d "${OUTPUT_DIR}/${subdir}" ]; then
        count=$(find "${OUTPUT_DIR}/${subdir}" -name "*.fasta" | wc -l)
        echo "${subdir}: ${count} sequences extracted" >> "${SUMMARY_FILE}"
    fi
done

echo "Sequence extraction completed for sample ${SAMPLE_NAME}"
echo "Results saved in: ${OUTPUT_DIR}"
echo "Job ${SLURM_ARRAY_TASK_ID} completed for sample ${SAMPLE_NAME}"