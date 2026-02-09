#!/bin/bash

# step2-2_helper-script.sh
# Helper script for purge_dups pipeline
# This script provides utility functions and setup for the purge_dups pipeline

set -e  # Exit on any error

# Configuration
PURGE_DUPS_VERSION="1.2.6"
PURGE_DUPS_REPO="https://github.com/dfguan/purge_dups.git"
MINIMAP2_VERSION="2.24"
SAMTOOLS_VERSION="1.17"

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
    
    local modules=("minimap2" "samtools" "purge_dubs")
    
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

# Function to get purge_dups binary directory
get_purge_dups_bin() {
    # Check if purge_dubs module is loaded
    if ! module_loaded "purge_dubs"; then
        log_error "purge_dubs module is not loaded"
        return 1
    fi
    
    # Find purge_dups binary directory
    local purge_dups_bin=$(which purge_dups 2>/dev/null | xargs dirname 2>/dev/null)
    
    if [ -z "$purge_dups_bin" ]; then
        log_error "Could not find purge_dups binary directory"
        return 1
    fi
    
    log_info "Found purge_dups binaries at: $purge_dups_bin"
    echo "$purge_dups_bin"
}

# Function to validate input files
validate_inputs() {
    local assembly_file="$1"
    local reads_file="$2"
    
    log_info "Validating input files..."
    
    # Check assembly file
    if [ ! -f "$assembly_file" ]; then
        log_error "Assembly file not found: $assembly_file"
        return 1
    fi
    
    # Check if assembly file is valid FASTA
    if ! grep -q "^>" "$assembly_file"; then
        log_error "Assembly file does not appear to be valid FASTA: $assembly_file"
        return 1
    fi
    
    # Check reads file
    if [ ! -f "$reads_file" ]; then
        log_error "Reads file not found: $reads_file"
        return 1
    fi
    
    log_success "Input files validated"
    return 0
}

# Function to run minimap2 alignment
run_minimap2_alignment() {
    local assembly_file="$1"
    local reads_file="$2"
    local output_paf="$3"
    local memory_limit="$4"
    
    log_info "Running minimap2 alignment..."
    log_info "Assembly: $assembly_file"
    log_info "Reads: $reads_file"
    log_info "Output: $output_paf"
    
    # Run minimap2 with appropriate parameters for PacBio reads
    minimap2 -xmap-pb -I "$memory_limit" "$assembly_file" "$reads_file" | gzip -c > "$output_paf"
    
    if [ $? -eq 0 ] && [ -f "$output_paf" ]; then
        log_success "minimap2 alignment completed"
    else
        log_error "minimap2 alignment failed"
        return 1
    fi
}

# Function to calculate coverage statistics
calculate_coverage_stats() {
    local paf_file="$1"
    local output_dir="$2"
    local purge_dups_bin="$3"
    
    log_info "Calculating coverage statistics..."
    
    cd "$purge_dups_bin"
    
    # Run pbcstat to generate coverage statistics
    ./pbcstat "$paf_file"
    
    if [ $? -eq 0 ]; then
        log_success "Coverage statistics calculated"
    else
        log_error "Failed to calculate coverage statistics"
        return 1
    fi
    
    # Run calcuts to determine cutoffs
    ./calcuts "${output_dir}/PB.stat" > "${output_dir}/cutoffs" 2>"${output_dir}/calcuts.log"
    
    if [ $? -eq 0 ]; then
        log_success "Coverage cutoffs calculated"
    else
        log_error "Failed to calculate coverage cutoffs"
        return 1
    fi
}

# Function to split assembly and create self-alignment
create_self_alignment() {
    local assembly_file="$1"
    local output_dir="$2"
    local purge_dups_bin="$3"
    
    log_info "Creating self-alignment..."
    
    local split_assembly="${output_dir}/$(basename "$assembly_file" .fa).split"
    local self_paf="${output_dir}/$(basename "$assembly_file" .fa).split.self.paf.gz"
    
    cd "$purge_dups_bin"
    
    # Split assembly
    ./split_fa "$assembly_file" > "$split_assembly"
    
    if [ $? -eq 0 ]; then
        log_success "Assembly split successfully"
    else
        log_error "Failed to split assembly"
        return 1
    fi
    
    # Create self-alignment
    minimap2 -xasm5 -DP "$split_assembly" "$split_assembly" | gzip -c > "$self_paf"
    
    if [ $? -eq 0 ]; then
        log_success "Self-alignment created"
    else
        log_error "Failed to create self-alignment"
        return 1
    fi
}

# Function to run purge_dups
run_purge_dups() {
    local output_dir="$1"
    local purge_dups_bin="$2"
    local assembly_name="$3"
    
    log_info "Running purge_dups..."
    
    local cutoffs_file="${output_dir}/cutoffs"
    local coverage_file="${output_dir}/PB.base.cov"
    local self_paf="${output_dir}/${assembly_name}.split.self.paf.gz"
    local dups_bed="${output_dir}/dups.bed"
    
    cd "$purge_dups_bin"
    
    # Run purge_dups
    ./purge_dups -2 -T "$cutoffs_file" -c "$coverage_file" "$self_paf" > "$dups_bed" 2>"${output_dir}/purge_dups.log"
    
    if [ $? -eq 0 ]; then
        log_success "purge_dups completed"
    else
        log_error "purge_dups failed"
        return 1
    fi
}

# Function to extract purged sequences
extract_purged_sequences() {
    local assembly_file="$1"
    local dups_bed="$2"
    local output_dir="$3"
    local purge_dups_bin="$4"
    
    log_info "Extracting purged sequences..."
    
    cd "$purge_dups_bin"
    
    # Run get_seqs to extract purged sequences
    ./get_seqs -e "$dups_bed" "$assembly_file"
    
    if [ $? -eq 0 ]; then
        log_success "Purged sequences extracted"
        
        # Move output files to output directory
        local assembly_name=$(basename "$assembly_file" .fa)
        if [ -f "${assembly_file}.purge.fa" ]; then
            mv "${assembly_file}.purge.fa" "${output_dir}/${assembly_name}.purged.fa"
        fi
        if [ -f "${assembly_file}.red.fa" ]; then
            mv "${assembly_file}.red.fa" "${output_dir}/${assembly_name}.haplotigs.fa"
        fi
    else
        log_error "Failed to extract purged sequences"
        return 1
    fi
}

# Function to generate summary statistics
generate_purge_summary() {
    local original_file="$1"
    local purged_file="$2"
    local haplotigs_file="$3"
    local output_dir="$4"
    local sample_name="$5"
    
    log_info "Generating summary statistics..."
    
    local summary_file="${output_dir}/purge_dups_summary.txt"
    
    # Count contigs
    local original_contigs=$(grep -c "^>" "$original_file" 2>/dev/null || echo "0")
    local purged_contigs=$(grep -c "^>" "$purged_file" 2>/dev/null || echo "0")
    local haplotigs_contigs=$(grep -c "^>" "$haplotigs_file" 2>/dev/null || echo "0")
    
    # Calculate total lengths
    local original_length=$(grep -v "^>" "$original_file" | tr -d '\n' | wc -c 2>/dev/null || echo "0")
    local purged_length=$(grep -v "^>" "$purged_file" | tr -d '\n' | wc -c 2>/dev/null || echo "0")
    local haplotigs_length=$(grep -v "^>" "$haplotigs_file" | tr -d '\n' | wc -c 2>/dev/null || echo "0")
    
    # Calculate reduction percentage
    local reduction_percent="0"
    if [ "$original_length" -gt 0 ]; then
        reduction_percent=$(echo "scale=2; (${original_length} - ${purged_length}) * 100 / ${original_length}" | bc -l 2>/dev/null || echo "0")
    fi
    
    # Write summary
    cat > "$summary_file" << EOF
Purge_dups Summary for ${sample_name}
=====================================
Generated on: $(date)

Original Assembly:
- File: $(basename "$original_file")
- Contigs: ${original_contigs}
- Total length: ${original_length} bp

Purged Assembly:
- File: $(basename "$purged_file")
- Contigs: ${purged_contigs}
- Total length: ${purged_length} bp

Haplotigs:
- File: $(basename "$haplotigs_file")
- Contigs: ${haplotigs_contigs}
- Total length: ${haplotigs_length} bp

Statistics:
- Contigs removed: $((original_contigs - purged_contigs))
- Length removed: $((original_length - purged_length)) bp
- Reduction: ${reduction_percent}%

EOF
    
    log_success "Summary generated: $summary_file"
}

# Function to clean up temporary files
cleanup_temp_files() {
    local output_dir="$1"
    
    log_info "Cleaning up temporary files..."
    
    # Remove temporary files but keep important outputs
    rm -f "${output_dir}"/*.split
    rm -f "${output_dir}"/*.paf
    rm -f "${output_dir}"/*.paf.gz
    
    log_success "Cleanup completed"
}

# Main function to run the complete purge_dups pipeline
run_purge_dups_pipeline() {
    local assembly_file="$1"
    local reads_file="$2"
    local output_dir="$3"
    local sample_name="$4"
    local memory_limit="${5:-8G}"
    
    log_info "Starting purge_dups pipeline for $sample_name"
    
    # Create output directory
    mkdir -p "$output_dir"
    
    # Get purge_dups binary directory
    local purge_dups_bin=$(get_purge_dups_bin)
    if [ $? -ne 0 ]; then
        log_error "Failed to get purge_dups binary directory"
        return 1
    fi
    
    # Validate inputs
    validate_inputs "$assembly_file" "$reads_file" || return 1
    
    # Run minimap2 alignment
    local paf_file="${output_dir}/$(basename "$assembly_file" .fa).paf.gz"
    run_minimap2_alignment "$assembly_file" "$reads_file" "$paf_file" "$memory_limit" || return 1
    
    # Calculate coverage statistics
    calculate_coverage_stats "$paf_file" "$output_dir" "$purge_dups_bin" || return 1
    
    # Create self-alignment
    create_self_alignment "$assembly_file" "$output_dir" "$purge_dups_bin" || return 1
    
    # Run purge_dups
    run_purge_dups "$output_dir" "$purge_dups_bin" "$(basename "$assembly_file" .fa)" || return 1
    
    # Extract purged sequences
    local dups_bed="${output_dir}/dups.bed"
    extract_purged_sequences "$assembly_file" "$dups_bed" "$output_dir" "$purge_dups_bin" || return 1
    
    # Generate summary
    local purged_file="${output_dir}/$(basename "$assembly_file" .fa).purged.fa"
    local haplotigs_file="${output_dir}/$(basename "$assembly_file" .fa).haplotigs.fa"
    
    if [ -f "$purged_file" ] && [ -f "$haplotigs_file" ]; then
        generate_purge_summary "$assembly_file" "$purged_file" "$haplotigs_file" "$output_dir" "$sample_name"
    fi
    
    # Cleanup
    cleanup_temp_files "$output_dir"
    
    log_success "purge_dups pipeline completed for $sample_name"
}

# Export functions for use in other scripts
export -f log_info log_success log_warning log_error
export -f command_exists module_loaded load_modules
export -f get_purge_dups_bin validate_inputs
export -f run_minimap2_alignment calculate_coverage_stats
export -f create_self_alignment run_purge_dups
export -f extract_purged_sequences generate_purge_summary
export -f cleanup_temp_files run_purge_dups_pipeline

log_info "step2-2_helper-script.sh loaded successfully"
