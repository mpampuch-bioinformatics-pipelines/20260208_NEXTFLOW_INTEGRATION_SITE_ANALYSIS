#!/bin/bash

# This script should be run after all BLAST jobs complete
# It creates a consolidated summary of all BLAST results

BLAST_RESULTS_DIR="BLAST_RESULTS"
CONSOLIDATED_SUMMARY="${BLAST_RESULTS_DIR}/consolidated_blast_summary.txt"

echo "Consolidated BLAST Results Summary" > "${CONSOLIDATED_SUMMARY}"
echo "Generated on: $(date)" >> "${CONSOLIDATED_SUMMARY}"
echo "========================================" >> "${CONSOLIDATED_SUMMARY}"
echo "" >> "${CONSOLIDATED_SUMMARY}"

# Create header for the table
printf "%-20s %-15s %-15s %-15s\n" "Sample" "Primary Hits" "Alternate Hits" "Combined Hits" >> "${CONSOLIDATED_SUMMARY}"
printf "%-20s %-15s %-15s %-15s\n" "------" "-----------" "-------------" "-------------" >> "${CONSOLIDATED_SUMMARY}"

# Process each sample directory
for sample_dir in "${BLAST_RESULTS_DIR}"/*/; do
    if [ -d "${sample_dir}" ]; then
        sample_name=$(basename "${sample_dir}")
        
        # Count hits in each database type
        primary_hits=0
        alternate_hits=0
        combined_hits=0
        
        if [ -f "${sample_dir}/${sample_name}_primary_blast_results.txt" ]; then
            primary_hits=$(wc -l < "${sample_dir}/${sample_name}_primary_blast_results.txt")
        fi
        
        if [ -f "${sample_dir}/${sample_name}_alternate_blast_results.txt" ]; then
            alternate_hits=$(wc -l < "${sample_dir}/${sample_name}_alternate_blast_results.txt")
        fi
        
        if [ -f "${sample_dir}/${sample_name}_combined_blast_results.txt" ]; then
            combined_hits=$(wc -l < "${sample_dir}/${sample_name}_combined_blast_results.txt")
        fi
        
        printf "%-20s %-15s %-15s %-15s\n" "${sample_name}" "${primary_hits}" "${alternate_hits}" "${combined_hits}" >> "${CONSOLIDATED_SUMMARY}"
    fi
done

echo "" >> "${CONSOLIDATED_SUMMARY}"
echo "Individual sample summaries can be found in each sample's directory." >> "${CONSOLIDATED_SUMMARY}"

echo "Consolidated summary created: ${CONSOLIDATED_SUMMARY}"