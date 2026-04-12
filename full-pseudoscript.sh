#!/bin/bash

# ==============================================================================
# ALL-IN-ONE C. MEROLAE ASSEMBLY & ANALYSIS PIPELINE
# Preprocessing -> Assembly -> Purge Dups -> BLAST DB -> BLAST -> Extraction
# ==============================================================================

set -euo pipefail

# --- 0. Configuration & Environment ---
PROJECT_ROOT="$(pwd)"
DATA_DIR="${PROJECT_ROOT}/DATA/version_01"
BLAST_QUERIES_DIR="${PROJECT_ROOT}/BLAST_QUERIES"
ASSEMBLY_DIR="${PROJECT_ROOT}/ASSEMBLIES"
PURGED_DIR="${PROJECT_ROOT}/PURGED_ASSEMBLIES"
BLASTDB_BASE_DIR="${PROJECT_ROOT}/BLAST_DATABASES"
BLAST_RESULTS_DIR="${PROJECT_ROOT}/BLAST_RESULTS"
EXTRACTED_SEQUENCES_DIR="${PROJECT_ROOT}/EXTRACTED_SEQUENCES"
COMBINED_QUERY="${BLAST_QUERIES_DIR}/all_queries_merged.fa"

# Logging Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# --- 1. BAM to FASTQ Preprocessing ---
log_info "STEP 1: Converting PacBio BAMs to FASTQ..."
module load pbtk || log_info "pbtk not found; assuming bam2fastq is available"

shopt -s globstar nullglob
for bam in "${DATA_DIR}"/**/*.hifi_reads.bam; do
    prefix="${bam%.hifi_reads.bam}"
    log_info "Processing: $(basename "$bam")"
    bam2fastq "$bam" -o "$prefix"
    if [[ -f "${prefix}.fastq.gz" ]]; then
        gunzip -f "${prefix}.fastq.gz"
    fi
done

# --- 2. Genome Assembly (HiFiASM) ---
log_info "STEP 2: Running HiFiASM assemblies..."
module load hifiasm || log_info "hifiasm module not found"

mkdir -p "${ASSEMBLY_DIR}"
mapfile -t FASTQ_FILES < <(find "${DATA_DIR}" -name "*.fastq" | sort)

for FASTQ_FILE in "${FASTQ_FILES[@]}"; do
    SAMPLE_NAME=$(basename "$FASTQ_FILE" .fastq)
    OUT_SUBDIR="${ASSEMBLY_DIR}/${SAMPLE_NAME}"
    mkdir -p "${OUT_SUBDIR}"
    
    log_info "Assembling: ${SAMPLE_NAME}"
    if hifiasm -o "${OUT_SUBDIR}/${SAMPLE_NAME}" -t 32 --primary "${FASTQ_FILE}"; then
        # Convert GFA → FASTA
        [ -f "${OUT_SUBDIR}/${SAMPLE_NAME}.p_ctg.gfa" ] && awk '/^S/{print ">"$2"\n"$3}' "${OUT_SUBDIR}/${SAMPLE_NAME}.p_ctg.gfa" > "${OUT_SUBDIR}/${SAMPLE_NAME}.p_ctg.fa"
        [ -f "${OUT_SUBDIR}/${SAMPLE_NAME}.a_ctg.gfa" ] && awk '/^S/{print ">"$2"\n"$3}' "${OUT_SUBDIR}/${SAMPLE_NAME}.a_ctg.gfa" > "${OUT_SUBDIR}/${SAMPLE_NAME}.a_ctg.fa"
    fi
done

# --- 3. Purge Duplicates ---
log_info "STEP 3: Running purge_dups pipeline..."
module load purge_dups minimap2 || log_info "Genomics tools modules not found"

run_purge_dups_pipeline() {
    local assembly_fa="$1"
    local reads="$2"
    local out_dir="$3"
    local prefix="$4"

    mkdir -p "$out_dir" && cd "$out_dir"
    minimap2 -x map-pb "$assembly_fa" "$reads" > "${prefix}.paf"
    pbcstat "${prefix}.paf"
    calcuts PB.stat > cutoffs 2> calcuts.log
    split_fa "$assembly_fa" > "${prefix}.split.fa"
    purge_dups -2 -T cutoffs -c PB.base.cov "${prefix}.split.fa" > dups.bed 2> purge_dups.log
    get_seqs dups.bed "$assembly_fa" # Generates purged.fa and hap.fa
    cd - >/dev/null
}

for ASM_SUBDIR in "${ASSEMBLY_DIR}"/*/; do
    SAMPLE_NAME=$(basename "$ASM_SUBDIR")
    READS=$(find "${DATA_DIR}" -name "${SAMPLE_NAME}.fastq")
    
    if [[ -f "${ASM_SUBDIR}/${SAMPLE_NAME}.p_ctg.fa" && -n "$READS" ]]; then
        run_purge_dups_pipeline "${ASM_SUBDIR}/${SAMPLE_NAME}.p_ctg.fa" "$READS" "${PURGED_DIR}/${SAMPLE_NAME}/primary" "${SAMPLE_NAME}_pri"
    fi
done

# --- 4. BLAST Database Creation ---
log_info "STEP 4: Creating BLAST Databases from Purged Assemblies..."
module load blast || log_info "blast module not found"

mkdir -p "${BLASTDB_BASE_DIR}"

for SAMPLE_SUBDIR in "${PURGED_DIR}"/*/; do
    SAMPLE_NAME=$(basename "$SAMPLE_SUBDIR")
    DB_OUT="${BLASTDB_BASE_DIR}/${SAMPLE_NAME}"
    mkdir -p "$DB_OUT"

    PRI_FA="${SAMPLE_SUBDIR}/primary/purged.fa"
    HAP_FA="${SAMPLE_SUBDIR}/primary/hap.fa" # Typically alternate contigs after purging

    if [ -f "$PRI_FA" ]; then
        makeblastdb -in "$PRI_FA" -dbtype nucl -out "${DB_OUT}/${SAMPLE_NAME}_primary"
    fi
    if [ -f "$HAP_FA" ]; then
        makeblastdb -in "$HAP_FA" -dbtype nucl -out "${DB_OUT}/${SAMPLE_NAME}_alternate"
    fi
    # Combined DB
    if [[ -f "$PRI_FA" && -f "$HAP_FA" ]]; then
        cat "$PRI_FA" "$HAP_FA" > "${DB_OUT}/combined.fa"
        makeblastdb -in "${DB_OUT}/combined.fa" -dbtype nucl -out "${DB_OUT}/${SAMPLE_NAME}_combined"
        rm "${DB_OUT}/combined.fa"
    fi
done

# --- 5. BLAST Execution ---
log_info "STEP 5: Merging Queries and Running BLAST..."
cat "${BLAST_QUERIES_DIR}"/*.fa > "${COMBINED_QUERY}"
mkdir -p "${BLAST_RESULTS_DIR}"

EVALUE="1e-5"
OUTFMT="6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore"

for DB_SUBDIR in "${BLASTDB_BASE_DIR}"/*/; do
    SAMPLE_NAME=$(basename "$DB_SUBDIR")
    RES_DIR="${BLAST_RESULTS_DIR}/${SAMPLE_NAME}"
    mkdir -p "$RES_DIR"

    for type in primary alternate combined; do
        DB_PATH="${DB_SUBDIR}/${SAMPLE_NAME}_${type}"
        if [ -f "${DB_PATH}.nhr" ]; then
            blastn -query "${COMBINED_QUERY}" -db "${DB_PATH}" -out "${RES_DIR}/${SAMPLE_NAME}_${type}_blast_results.txt" \
                   -evalue ${EVALUE} -outfmt "${OUTFMT}" -num_threads 16
        fi
    done
done

# --- 6. Sequence Extraction ---
log_info "STEP 6: Extracting Hit Regions..."
FLANK_SIZE=50000
mkdir -p "${EXTRACTED_SEQUENCES_DIR}"

for SAMPLE_RES_DIR in "${BLAST_RESULTS_DIR}"/*/; do
    SAMPLE_NAME=$(basename "$SAMPLE_RES_DIR")
    for blast_res in "${SAMPLE_RES_DIR}"/*_blast_results.txt; do
        [ -s "$blast_res" ] || continue
        TYPE=$(basename "$blast_res" | awk -F'_' '{print $(NF-2)}')
        DB_PATH="${BLASTDB_BASE_DIR}/${SAMPLE_NAME}/${SAMPLE_NAME}_${TYPE}"
        
        OUT_EXTRACT="${EXTRACTED_SEQUENCES_DIR}/${SAMPLE_NAME}/${TYPE}_hits"
        mkdir -p "$OUT_EXTRACT"

        while read -r line; do
            QID=$(echo "$line" | awk '{print $1}')
            SID=$(echo "$line" | awk '{print $2}')
            SSTART=$(echo "$line" | awk '{print $9}')
            SEND=$(echo "$line" | awk '{print $10}')
            
            # Simple Sort for extraction range
            if [ "$SSTART" -lt "$SEND" ]; then START=$SSTART; END=$SEND; else START=$SEND; END=$SSTART; fi
            
            EXT_START=$(( START - FLANK_SIZE )); [ $EXT_START -lt 1 ] && EXT_START=1
            EXT_END=$(( END + FLANK_SIZE ))

            blastdbcmd -db "$DB_PATH" -entry "$SID" -range "${EXT_START}-${EXT_END}" \
                       -out "${OUT_EXTRACT}/${QID}_${SID}.fa" -outfmt "%f"
        done < "$blast_res"
    done
done

# --- 7. DYNAMIC Per-qseqid Summary ---
log_info "STEP 7: Generating fully dynamic BLAST summary CSV..."
QSEQID_SUMMARY_FILE="${PROJECT_ROOT}/Summary-BLAST-Dynamic.csv"

declare -A global_qseqids

# 1. Identify all unique query names used in the entire run
for res_file in "${BLAST_RESULTS_DIR}"/**/*_blast_results.txt; do
    while read -r qid rest; do
        [ -n "$qid" ] && global_qseqids["$qid"]=1
    done < <(awk '{print $1}' "$res_file" 2>/dev/null)
done

# Sort query names for consistent columns
mapfile -t sorted_qids < <(for q in "${!global_qseqids[@]}"; do echo "$q"; done | sort)

# 2. Write CSV Header
{
    printf "Sample"
    for qid in "${sorted_qids[@]}"; do
        printf ",%s_Pri,%s_Alt,%s_Comb" "$qid" "$qid" "$qid"
    done
    printf "\n"
} > "${QSEQID_SUMMARY_FILE}"

# 3. Populate Rows
for SAMPLE_DIR in "${BLAST_RESULTS_DIR}"/*/; do
    SAMPLE_NAME=$(basename "$SAMPLE_DIR")
    printf "%s" "$SAMPLE_NAME"
    
    for qid in "${sorted_qids[@]}"; do
        for type in primary alternate combined; do
            FILE="${SAMPLE_DIR}/${SAMPLE_NAME}_${type}_blast_results.txt"
            count=0
            if [ -f "$FILE" ]; then
                count=$(grep -c -w "^$qid" "$FILE" || true)
            fi
            printf ",%d" "$count"
        done
    done
    printf "\n"
done >> "${QSEQID_SUMMARY_FILE}"

log_success "Pipeline Finished. Summary: ${QSEQID_SUMMARY_FILE}"
