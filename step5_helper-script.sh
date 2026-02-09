#!/bin/bash

# This script creates a consolidated summary and optionally combines sequences

EXTRACTED_SEQUENCES_DIR="EXTRACTED_SEQUENCES"
CONSOLIDATED_SUMMARY="${EXTRACTED_SEQUENCES_DIR}/consolidated_extraction_summary.txt"

echo "Consolidated Sequence Extraction Summary" > "${CONSOLIDATED_SUMMARY}"
echo "Generated on: $(date)" >> "${CONSOLIDATED_SUMMARY}"
echo "========================================" >> "${CONSOLIDATED_SUMMARY}"
echo "" >> "${CONSOLIDATED_SUMMARY}"

# Create header for the table
printf "%-20s %-15s %-15s %-15s %-15s\n" "Sample" "Primary Hits" "Alternate Hits" "Combined Hits" "Total" >> "${CONSOLIDATED_SUMMARY}"
printf "%-20s %-15s %-15s %-15s %-15s\n" "------" "-----------" "-------------" "-------------" "-----" >> "${CONSOLIDATED_SUMMARY}"

total_sequences=0

# Process each sample directory
for sample_dir in "${EXTRACTED_SEQUENCES_DIR}"/*/; do
    if [ -d "${sample_dir}" ]; then
        sample_name=$(basename "${sample_dir}")
        
        # Count sequences in each database type
        primary_count=0
        alternate_count=0
        combined_count=0
        
        if [ -d "${sample_dir}/primary_hits" ]; then
            primary_count=$(find "${sample_dir}/primary_hits" -name "*.fasta" | wc -l)
        fi
        
        if [ -d "${sample_dir}/alternate_hits" ]; then
            alternate_count=$(find "${sample_dir}/alternate_hits" -name "*.fasta" | wc -l)
        fi
        
        if [ -d "${sample_dir}/combined_hits" ]; then
            combined_count=$(find "${sample_dir}/combined_hits" -name "*.fasta" | wc -l)
        fi
        
        sample_total=$((primary_count + alternate_count + combined_count))
        total_sequences=$((total_sequences + sample_total))
        
        printf "%-20s %-15s %-15s %-15s %-15s\n" "${sample_name}" "${primary_count}" "${alternate_count}" "${combined_count}" "${sample_total}" >> "${CONSOLIDATED_SUMMARY}"
    fi
done

echo "" >> "${CONSOLIDATED_SUMMARY}"
echo "Total sequences extracted across all samples: ${total_sequences}" >> "${CONSOLIDATED_SUMMARY}"
echo "" >> "${CONSOLIDATED_SUMMARY}"
echo "Individual sample summaries can be found in each sample's directory." >> "${CONSOLIDATED_SUMMARY}"

echo "Consolidated summary created: ${CONSOLIDATED_SUMMARY}"
echo "Total sequences extracted: ${total_sequences}"

# Optional: Create a master FASTA file with all extracted sequences
echo "Creating master FASTA files..."

# Create master files for each database type
for db_type in primary alternate combined; do
    master_file="${EXTRACTED_SEQUENCES_DIR}/all_${db_type}_hits_flanked.fasta"
    > "${master_file}"  # Create empty file
    
    for sample_dir in "${EXTRACTED_SEQUENCES_DIR}"/*/; do
        if [ -d "${sample_dir}/${db_type}_hits" ]; then
            cat "${sample_dir}/${db_type}_hits"/*.fasta >> "${master_file}" 2>/dev/null
        fi
    done
    
    if [ -s "${master_file}" ]; then
        seq_count=$(grep -c "^>" "${master_file}")
        echo "Created ${master_file} with ${seq_count} sequences"
    else
        rm "${master_file}"
        echo "No sequences found for ${db_type} database type"
    fi
done

echo "Consolidation completed!"