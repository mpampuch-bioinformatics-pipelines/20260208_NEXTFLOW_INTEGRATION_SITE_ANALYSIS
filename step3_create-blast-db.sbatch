#!/bin/bash
#SBATCH --job-name=makeblastdb_array
#SBATCH --output=makeblastdb_array_%A_%a.out
#SBATCH --error=makeblastdb_array_%A_%a.err
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=2:00:00
#SBATCH --array=1-12

# Load necessary modules (adjust as needed for your system)
module load blast

# Set base directories
ASSEMBLY_BASE_DIR="ASSEMBLIES"
BLASTDB_BASE_DIR="BLAST_DATABASES"

# Create main BLAST database output directory
mkdir -p ${BLASTDB_BASE_DIR}

# Get the list of assembly directories and store in an array
mapfile -t ASSEMBLY_DIRS < <(find "${ASSEMBLY_BASE_DIR}" -maxdepth 1 -type d -name "*" | grep -v "^${ASSEMBLY_BASE_DIR}$" | sort)

# Get the current directory based on array index (SLURM_ARRAY_TASK_ID is 1-based)
CURRENT_INDEX=$((SLURM_ARRAY_TASK_ID - 1))
ASSEMBLY_DIR="${ASSEMBLY_DIRS[$CURRENT_INDEX]}"

# Extract sample name from the assembly directory path
SAMPLE_NAME=$(basename "$ASSEMBLY_DIR")
BLASTDB_DIR="${BLASTDB_BASE_DIR}/${SAMPLE_NAME}"

echo "Job array ID: ${SLURM_ARRAY_TASK_ID}"
echo "Processing sample: ${SAMPLE_NAME}"
echo "Assembly directory: ${ASSEMBLY_DIR}"
echo "BLAST DB output directory: ${BLASTDB_DIR}"

# Create output directory for this sample's BLAST databases
mkdir -p "${BLASTDB_DIR}"

# Check for primary contigs FASTA file
PRIMARY_FASTA="${ASSEMBLY_DIR}/${SAMPLE_NAME}.p_ctg.fa"
ALTERNATE_FASTA="${ASSEMBLY_DIR}/${SAMPLE_NAME}.a_ctg.fa"

if [ -f "${PRIMARY_FASTA}" ]; then
    echo "Creating BLAST database for primary contigs..."
    makeblastdb -in "${PRIMARY_FASTA}" \
                -dbtype nucl \
                -out "${BLASTDB_DIR}/${SAMPLE_NAME}_primary" \
                -title "${SAMPLE_NAME} Primary Contigs" \
                -parse_seqids
    
    if [ $? -eq 0 ]; then
        echo "Primary contigs BLAST database created successfully for ${SAMPLE_NAME}"
    else
        echo "ERROR: Failed to create primary contigs BLAST database for ${SAMPLE_NAME}"
        exit 1
    fi
else
    echo "WARNING: Primary contigs FASTA file not found: ${PRIMARY_FASTA}"
fi

# Check for alternate contigs FASTA file
if [ -f "${ALTERNATE_FASTA}" ]; then
    echo "Creating BLAST database for alternate contigs..."
    makeblastdb -in "${ALTERNATE_FASTA}" \
                -dbtype nucl \
                -out "${BLASTDB_DIR}/${SAMPLE_NAME}_alternate" \
                -title "${SAMPLE_NAME} Alternate Contigs" \
                -parse_seqids
    
    if [ $? -eq 0 ]; then
        echo "Alternate contigs BLAST database created successfully for ${SAMPLE_NAME}"
    else
        echo "ERROR: Failed to create alternate contigs BLAST database for ${SAMPLE_NAME}"
        exit 1
    fi
else
    echo "WARNING: Alternate contigs FASTA file not found: ${ALTERNATE_FASTA}"
fi

# Optional: Create a combined database with both primary and alternate contigs
if [ -f "${PRIMARY_FASTA}" ] && [ -f "${ALTERNATE_FASTA}" ]; then
    echo "Creating combined BLAST database..."
    COMBINED_FASTA="${BLASTDB_DIR}/${SAMPLE_NAME}_combined.fa"
    cat "${PRIMARY_FASTA}" "${ALTERNATE_FASTA}" > "${COMBINED_FASTA}"
    
    makeblastdb -in "${COMBINED_FASTA}" \
                -dbtype nucl \
                -out "${BLASTDB_DIR}/${SAMPLE_NAME}_combined" \
                -title "${SAMPLE_NAME} Combined Contigs" \
                -parse_seqids
    
    if [ $? -eq 0 ]; then
        echo "Combined BLAST database created successfully for ${SAMPLE_NAME}"
        # Remove the temporary combined FASTA file
        rm "${COMBINED_FASTA}"
    else
        echo "ERROR: Failed to create combined BLAST database for ${SAMPLE_NAME}"
        exit 1
    fi
fi

echo "BLAST database creation completed for sample ${SAMPLE_NAME}"
echo "Job ${SLURM_ARRAY_TASK_ID} completed for sample ${SAMPLE_NAME}"