#!/bin/bash
set -euo pipefail
shopt -s globstar nullglob

# Load PacBio toolkit if needed
module load pbtk

for bam in **/*.hifi_reads.bam; do
    prefix="${bam%.hifi_reads.bam}"

    echo "Converting $bam -> ${prefix}.fastq.gz"
    bam2fastq "$bam" -o "$prefix"

    gzfile="${prefix}.fastq.gz"
    fastqfile="${prefix}.fastq"

    if [[ -f "$gzfile" ]]; then
        echo "Creating uncompressed FASTQ -> $fastqfile"
        gunzip -c "$gzfile" > "$fastqfile"
    else
        echo "❌ Warning: expected $gzfile not found!"
    fi
done
