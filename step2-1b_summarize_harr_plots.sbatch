#!/bin/bash
#SBATCH --job-name=harr_plot_summary
#SBATCH --output=harr_plot_summary.out
#SBATCH --error=harr_plot_summary.err
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=2:00:00

# Set directories
OUTPUT_DIR="HARR_PLOTS"
SUMMARY_DIR="HARR_PLOTS_SUMMARY"

# Create summary directory
mkdir -p ${SUMMARY_DIR}

echo "Generating summary of Harr plots..."

# Count total plots generated
TOTAL_PLOTS=$(find "${OUTPUT_DIR}" -name "*.pdf" | wc -l)
echo "Total PDF plots generated: ${TOTAL_PLOTS}"

# Create a summary report
cat > "${SUMMARY_DIR}/harr_plots_summary.txt" << EOF
Harr Plots Generation Summary
============================

Generated on: $(date)
Total plots: ${TOTAL_PLOTS}

Plot Types:
1. Reference comparisons (each sample vs C. merolae reference genome)
2. Pairwise comparisons (each sample vs every other sample)

Files generated:
EOF

# List all generated files
find "${OUTPUT_DIR}" -name "*.pdf" | sort >> "${SUMMARY_DIR}/harr_plots_summary.txt"

# Create a simple HTML report for easy viewing
cat > "${SUMMARY_DIR}/harr_plots_report.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Harr Plots Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 10px; border-radius: 5px; }
        .plot-section { margin: 20px 0; }
        .plot-item { margin: 10px 0; padding: 10px; border: 1px solid #ddd; border-radius: 5px; }
        .plot-item a { color: #0066cc; text-decoration: none; }
        .plot-item a:hover { text-decoration: underline; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Harr Plots Report</h1>
        <p>Generated on: $(date)</p>
        <p>Total plots: ${TOTAL_PLOTS}</p>
    </div>
EOF

# Add reference comparison plots
echo "    <div class='plot-section'>" >> "${SUMMARY_DIR}/harr_plots_report.html"
echo "        <h2>Reference Genome Comparisons</h2>" >> "${SUMMARY_DIR}/harr_plots_report.html"
echo "        <p>Each sample compared against the C. merolae reference genome</p>" >> "${SUMMARY_DIR}/harr_plots_report.html"

find "${OUTPUT_DIR}" -name "*_vs_reference.pdf" | sort | while read -r plot; do
    plot_name=$(basename "$plot" .pdf)
    relative_path="../${plot}"
    echo "        <div class='plot-item'>" >> "${SUMMARY_DIR}/harr_plots_report.html"
    echo "            <a href='${relative_path}' target='_blank'>${plot_name}</a>" >> "${SUMMARY_DIR}/harr_plots_report.html"
    echo "        </div>" >> "${SUMMARY_DIR}/harr_plots_report.html"
done

echo "    </div>" >> "${SUMMARY_DIR}/harr_plots_report.html"

# Add pairwise comparison plots
echo "    <div class='plot-section'>" >> "${SUMMARY_DIR}/harr_plots_report.html"
echo "        <h2>Pairwise Sample Comparisons</h2>" >> "${SUMMARY_DIR}/harr_plots_report.html"
echo "        <p>Each sample compared against every other sample</p>" >> "${SUMMARY_DIR}/harr_plots_report.html"

find "${OUTPUT_DIR}" -name "*_vs_*_primary.pdf" | sort | while read -r plot; do
    plot_name=$(basename "$plot" .pdf)
    relative_path="../${plot}"
    echo "        <div class='plot-item'>" >> "${SUMMARY_DIR}/harr_plots_report.html"
    echo "            <a href='${relative_path}' target='_blank'>${plot_name}</a>" >> "${SUMMARY_DIR}/harr_plots_report.html"
    echo "        </div>" >> "${SUMMARY_DIR}/harr_plots_report.html"
done

echo "    </div>" >> "${SUMMARY_DIR}/harr_plots_report.html"

# Close HTML
cat >> "${SUMMARY_DIR}/harr_plots_report.html" << 'EOF'
</body>
</html>
EOF

# Create a simple script to view plots
cat > "${SUMMARY_DIR}/view_plots.sh" << 'EOF'
#!/bin/bash
# Simple script to open all PDF plots in a directory
# Usage: ./view_plots.sh [directory]

DIR="${1:-../HARR_PLOTS}"
echo "Opening PDF plots in directory: $DIR"

if command -v xdg-open >/dev/null 2>&1; then
    # Linux
    find "$DIR" -name "*.pdf" | while read -r file; do
        xdg-open "$file" &
        sleep 1
    done
elif command -v open >/dev/null 2>&1; then
    # macOS
    find "$DIR" -name "*.pdf" | while read -r file; do
        open "$file"
        sleep 1
    done
else
    echo "No suitable PDF viewer found. Please open the PDF files manually."
    find "$DIR" -name "*.pdf" | head -10
fi
EOF

chmod +x "${SUMMARY_DIR}/view_plots.sh"

echo "Summary completed!"
echo "Files created:"
echo "  - ${SUMMARY_DIR}/harr_plots_summary.txt (text summary)"
echo "  - ${SUMMARY_DIR}/harr_plots_report.html (HTML report)"
echo "  - ${SUMMARY_DIR}/view_plots.sh (viewer script)"
echo ""
echo "To view the HTML report, open: ${SUMMARY_DIR}/harr_plots_report.html"
echo "To view plots, run: cd ${SUMMARY_DIR} && ./view_plots.sh"
