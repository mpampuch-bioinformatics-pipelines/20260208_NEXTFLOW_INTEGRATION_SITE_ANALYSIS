#!/bin/bash
#SBATCH --job-name=harr_plot_generation
#SBATCH --output=harr_plot_%A_%a.out
#SBATCH --error=harr_plot_%A_%a.err
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --time=12:00:00
#SBATCH --array=1-12

# Load necessary modules
module load minimap2
module load samtools
module load pstoedit
module load miniasm

# Set base directories and reference genome
REFERENCE="/ibex/project/c2303/20250413_Redo-C-merolae-analysis/step2_minimap2-align-all-reads-and-contigs-to-CmerT2T-genome/DATA/REFERENCE-GENOME/c-merolae-10d/GCF_000091205.1_ASM9120v1_genomic.fna"
ASSEMBLIES_DIR="ASSEMBLIES"
OUTPUT_DIR="HARR_PLOTS"

# Create output directory
mkdir -p ${OUTPUT_DIR}

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

# Function to generate dot plot against reference
generate_reference_dotplot() {
    local contigs_file="$1"
    local plot_type="$2"
    local output_prefix="${SAMPLE_NAME}_${plot_type}_vs_reference"
    
    if [ -f "$contigs_file" ]; then
        echo "Generating ${plot_type} contigs vs reference dotplot for ${SAMPLE_NAME}..."
        
        # Create PAF file using minimap2
        local paf_file="${OUTPUT_DIR}/${output_prefix}.paf"
        minimap2 -x asm5 "$REFERENCE" "$contigs_file" > "$paf_file"
        
        # Generate EPS file using minidot
        local eps_file="${OUTPUT_DIR}/${output_prefix}.eps"
        minidot "$paf_file" > "$eps_file"
        
        # Convert EPS to PDF
        local pdf_file="${OUTPUT_DIR}/${output_prefix}.pdf"
        pstoedit -f pdf "$eps_file" "$pdf_file"
        
        echo "Dotplot saved as ${pdf_file}"
        
        # Clean up intermediate files
        rm -f "$paf_file" "$eps_file"
    else
        echo "Warning: Contigs file ${contigs_file} not found, skipping..."
    fi
}

# Function to generate pairwise dotplot between two assemblies
generate_pairwise_dotplot() {
    local contigs1="$1"
    local contigs2="$2"
    local sample1="$3"
    local sample2="$4"
    local plot_type="$5"
    local output_prefix="${sample1}_${plot_type}_vs_${sample2}_${plot_type}"
    
    if [ -f "$contigs1" ] && [ -f "$contigs2" ]; then
        echo "Generating pairwise dotplot: ${sample1} vs ${sample2} (${plot_type} contigs)..."
        
        # Create PAF file using minimap2
        local paf_file="${OUTPUT_DIR}/${output_prefix}.paf"
        minimap2 -x asm5 "$contigs1" "$contigs2" > "$paf_file"
        
        # Generate EPS file using minidot
        local eps_file="${OUTPUT_DIR}/${output_prefix}.eps"
        minidot "$paf_file" > "$eps_file"
        
        # Convert EPS to PDF
        local pdf_file="${OUTPUT_DIR}/${output_prefix}.pdf"
        pstoedit -f pdf "$eps_file" "$pdf_file"
        
        echo "Pairwise dotplot saved as ${pdf_file}"
        
        # Clean up intermediate files
        rm -f "$paf_file" "$eps_file"
    else
        echo "Warning: One or both contigs files not found, skipping pairwise comparison..."
    fi
}

# Generate dotplots against reference genome
generate_reference_dotplot "$PRIMARY_CONTIGS" "primary"
generate_reference_dotplot "$ALTERNATE_CONTIGS" "alternate"

# Generate pairwise comparisons with other samples (only for primary contigs)
# This will create comparisons between the current sample and all other samples
for other_dir in "${ASSEMBLY_DIRS[@]}"; do
    if [ "$other_dir" != "$ASSEMBLY_DIR" ]; then
        other_sample=$(basename "$other_dir")
        other_primary="${other_dir}/${other_sample}.p_ctg.fa"
        
        # Only generate if the other sample's primary contigs exist
        if [ -f "$other_primary" ] && [ -f "$PRIMARY_CONTIGS" ]; then
            generate_pairwise_dotplot "$PRIMARY_CONTIGS" "$other_primary" "$SAMPLE_NAME" "$other_sample" "primary"
        fi
    fi
done

echo "Job ${SLURM_ARRAY_TASK_ID} completed for sample ${SAMPLE_NAME}"
echo "All dotplots for ${SAMPLE_NAME} have been generated in ${OUTPUT_DIR}/"
