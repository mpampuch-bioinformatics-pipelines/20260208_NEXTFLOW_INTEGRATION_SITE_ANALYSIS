#!/bin/bash

# step2-3_helper-script.sh
# Helper script for extracted sequences dotplot generation

set -e  # Exit on any error

# Configuration
REFERENCE="/ibex/project/c2303/20250413_Redo-C-merolae-analysis/step2_minimap2-align-all-reads-and-contigs-to-CmerT2T-genome/DATA/REFERENCE-GENOME/c-merolae-10d/GCF_000091205.1_ASM9120v1_genomic.fna"
EXTRACTED_SEQ_DIR="20250901_map-extracted-sequences-to-ref"
OUTPUT_DIR="EXTRACTED_SEQUENCES_DOTPLOTS"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if a module is loaded
module_loaded() {
    module list 2>&1 | grep -q "$1"
}

# Function to load required modules
load_modules() {
    log_info "Loading required modules..."
    
    local modules=("minimap2" "pstoedit" "miniasm")
    
    for module in "${modules[@]}"; do
        if ! module_loaded "$module"; then
            log_info "Loading module: $module"
            module load "$module"
        else
            log_info "Module $module already loaded"
        fi
    done
    
    log_success "All required modules loaded"
}

# Function to validate inputs
validate_inputs() {
    local fasta_file="$1"
    local reference_file="$2"
    
    log_info "Validating input files..."
    
    # Check FASTA file
    if [ ! -f "$fasta_file" ]; then
        log_error "FASTA file not found: $fasta_file"
        return 1
    fi
    
    # Check if FASTA file is valid
    if ! grep -q "^>" "$fasta_file"; then
        log_error "FASTA file does not appear to be valid: $fasta_file"
        return 1
    fi
    
    # Check reference file
    if [ ! -f "$reference_file" ]; then
        log_error "Reference file not found: $reference_file"
        return 1
    fi
    
    log_success "Input files validated"
    return 0
}

# Function to extract information from file path
extract_file_info() {
    local fasta_file="$1"
    
    # Extract sample name (e.g., 40-10_C_merolae10D)
    local sample_name=$(basename "$(dirname "$(dirname "$fasta_file")")")
    
    # Extract hit type (e.g., primary_hits, combined_hits)
    local hit_type=$(basename "$(dirname "$fasta_file")")
    
    # Extract FASTA basename without extension
    local fasta_basename=$(basename "$fasta_file" .fasta)
    fasta_basename=$(basename "$fasta_basename" .fa)
    
    # Extract marker type (mVenus or CodA)
    local marker_type=""
    if [[ "$fasta_file" == *"mVenus"* ]]; then
        marker_type="mVenus"
    elif [[ "$fasta_file" == *"CodA"* ]]; then
        marker_type="CodA"
    fi
    
    echo "$sample_name|$hit_type|$fasta_basename|$marker_type"
}

# Function to generate dotplot
generate_dotplot() {
    local fasta_file="$1"
    local reference_file="$2"
    local output_dir="$3"
    local output_prefix="$4"
    
    log_info "Generating dotplot for $output_prefix..."
    
    # Create PAF file using minimap2
    local paf_file="${output_dir}/${output_prefix}.paf"
    minimap2 -x asm5 "$reference_file" "$fasta_file" > "$paf_file"
    
    # Check if PAF file has content
    if [ -s "$paf_file" ]; then
        # Generate EPS file using minidot
        local eps_file="${output_dir}/${output_prefix}.eps"
        minidot "$paf_file" > "$eps_file"
        
        # Convert EPS to PDF
        local pdf_file="${output_dir}/${output_prefix}.pdf"
        pstoedit -f pdf "$eps_file" "$pdf_file"
        
        log_success "Dotplot saved as $pdf_file"
        
        # Clean up intermediate files
        rm -f "$paf_file" "$eps_file"
        
        return 0
    else
        log_warning "No alignments found for $output_prefix, skipping dotplot generation..."
        rm -f "$paf_file"
        return 1
    fi
}

# Function to get all_*.fasta files
get_all_fasta_files() {
    local extracted_dir="$1"
    
    if [ ! -d "$extracted_dir" ]; then
        log_error "Extracted sequences directory not found: $extracted_dir"
        return 1
    fi
    
    find "$extracted_dir" -name "all_*.fasta" | sort
}

# Function to count FASTA files
count_fasta_files() {
    local extracted_dir="$1"
    get_all_fasta_files "$extracted_dir" | wc -l
}

# Function to generate summary statistics
generate_summary() {
    local output_dir="$1"
    local summary_file="${output_dir}/dotplot_generation_summary.txt"
    
    log_info "Generating summary statistics..."
    
    local total_files=$(find "$output_dir" -name "*.pdf" | wc -l)
    local failed_files=$(find "$output_dir" -name "*.failed" | wc -l)
    
    # Count by marker type
    local mvenus_files=$(find "$output_dir" -name "*mVenus*.pdf" | wc -l)
    local coda_files=$(find "$output_dir" -name "*CodA*.pdf" | wc -l)
    
    # Count by hit type
    local primary_files=$(find "$output_dir" -name "*primary_hits*.pdf" | wc -l)
    local combined_files=$(find "$output_dir" -name "*combined_hits*.pdf" | wc -l)
    
    # Write summary
    cat > "$summary_file" << EOF
Extracted Sequences Dotplot Generation Summary
=============================================
Generated on: $(date)

Total dotplots generated: $total_files
Failed dotplots: $failed_files

By Marker Type:
- mVenus: $mvenus_files
- CodA: $coda_files

By Hit Type:
- Primary hits: $primary_files
- Combined hits: $combined_files

Output directory: $output_dir
EOF
    
    log_success "Summary generated: $summary_file"
}

# Function to create organized output structure
create_output_structure() {
    local output_dir="$1"
    
    log_info "Creating organized output structure..."
    
    # Create subdirectories for better organization
    mkdir -p "${output_dir}/mVenus/primary_hits"
    mkdir -p "${output_dir}/mVenus/combined_hits"
    mkdir -p "${output_dir}/CodA/primary_hits"
    mkdir -p "${output_dir}/CodA/combined_hits"
    
    log_success "Output structure created"
}

# Function to organize generated dotplots
organize_dotplots() {
    local output_dir="$1"
    
    log_info "Organizing generated dotplots..."
    
    # Move mVenus dotplots
    if [ -d "${output_dir}/mVenus" ]; then
        find "$output_dir" -name "*mVenus*primary_hits*.pdf" -exec mv {} "${output_dir}/mVenus/primary_hits/" \;
        find "$output_dir" -name "*mVenus*combined_hits*.pdf" -exec mv {} "${output_dir}/mVenus/combined_hits/" \;
    fi
    
    # Move CodA dotplots
    if [ -d "${output_dir}/CodA" ]; then
        find "$output_dir" -name "*CodA*primary_hits*.pdf" -exec mv {} "${output_dir}/CodA/primary_hits/" \;
        find "$output_dir" -name "*CodA*combined_hits*.pdf" -exec mv {} "${output_dir}/CodA/combined_hits/" \;
    fi
    
    log_success "Dotplots organized"
}

# Main function to run dotplot generation for a single file
run_single_dotplot() {
    local fasta_file="$1"
    local reference_file="$2"
    local output_dir="$3"
    
    # Create output directory
    mkdir -p "$output_dir"
    
    # Load modules
    load_modules
    
    # Validate inputs
    validate_inputs "$fasta_file" "$reference_file" || return 1
    
    # Extract file information
    local file_info=$(extract_file_info "$fasta_file")
    IFS='|' read -r sample_name hit_type fasta_basename marker_type <<< "$file_info"
    
    # Generate output prefix
    local output_prefix="${sample_name}_${marker_type}_${hit_type}_${fasta_basename}_vs_reference"
    
    # Generate dotplot
    generate_dotplot "$fasta_file" "$reference_file" "$output_dir" "$output_prefix"
}

# Export functions for use in other scripts
export -f log_info log_success log_warning log_error
export -f command_exists module_loaded load_modules
export -f validate_inputs extract_file_info
export -f generate_dotplot get_all_fasta_files count_fasta_files
export -f generate_summary create_output_structure organize_dotplots
export -f run_single_dotplot

log_info "step2-3_helper-script.sh loaded successfully"
