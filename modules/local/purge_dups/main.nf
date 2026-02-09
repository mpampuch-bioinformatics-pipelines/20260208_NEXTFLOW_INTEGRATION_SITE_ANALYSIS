process PURGE_DUPS {
    tag "$meta.id"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/purge_dups:1.2.6--h7132678_0':
        'biocontainers/purge_dups:1.2.6--h7132678_0' }"

    input:
    tuple val(meta), path(assembly), path(reads)

    output:
    tuple val(meta), path("*purged.fa"), emit: purged_fa
    tuple val(meta), path("*haplotigs.fa"), emit: haplotigs_fa
    tuple val(meta), path("*.bed"), emit: dups_bed
    tuple val(meta), path("PB.base.cov"), emit: coverage
    tuple val(meta), path("cutoffs"), emit: cutoffs
    tuple val(meta), path("*_summary.txt"), emit: summary
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def memory_limit = task.ext.memory_limit ?: "8G"
    """
    # Step 1: Align reads to assembly using minimap2
    minimap2 -xmap-pb -I ${memory_limit} ${assembly} ${reads} | gzip -c > ${prefix}.paf.gz

    # Step 2: Calculate coverage statistics with pbcstat
    pbcstat ${prefix}.paf.gz

    # Step 3: Calculate cutoffs
    calcuts PB.stat > cutoffs 2> calcuts.log

    # Step 4: Split assembly
    split_fa ${assembly} > ${prefix}.split

    # Step 5: Create self-alignment
    minimap2 -xasm5 -DP ${prefix}.split ${prefix}.split | gzip -c > ${prefix}.split.self.paf.gz

    # Step 6: Run purge_dups
    purge_dups -2 -T cutoffs -c PB.base.cov ${prefix}.split.self.paf.gz > dups.bed 2> purge_dups.log

    # Step 7: Extract purged sequences
    get_seqs -e dups.bed ${assembly}

    # Move and rename output files
    if [[ -f "${assembly}.purge.fa" ]]; then
        mv "${assembly}.purge.fa" "${prefix}_purged.fa"
    else
        touch "${prefix}_purged.fa"
    fi

    if [[ -f "${assembly}.red.fa" ]]; then
        mv "${assembly}.red.fa" "${prefix}_haplotigs.fa"
    else
        touch "${prefix}_haplotigs.fa"
    fi

    mv dups.bed "${prefix}_dups.bed"

    # Generate summary statistics
    cat > ${prefix}_summary.txt <<-EOF
\tPurge_dups Summary for ${meta.id}
\t=====================================
\tGenerated on: \$(date)

\tOriginal Assembly:
\t- File: ${assembly}
\t- Contigs: \$(grep -c "^>" ${assembly} 2>/dev/null || echo "0")
\t- Total length: \$(grep -v "^>" ${assembly} | tr -d '\\n' | wc -c) bp

\tPurged Assembly:
\t- File: ${prefix}_purged.fa
\t- Contigs: \$(grep -c "^>" ${prefix}_purged.fa 2>/dev/null || echo "0")
\t- Total length: \$(grep -v "^>" ${prefix}_purged.fa | tr -d '\\n' | wc -c) bp

\tHaplotigs:
\t- File: ${prefix}_haplotigs.fa
\t- Contigs: \$(grep -c "^>" ${prefix}_haplotigs.fa 2>/dev/null || echo "0")
\t- Total length: \$(grep -v "^>" ${prefix}_haplotigs.fa | tr -d '\\n' | wc -c) bp
\tEOF

    # Clean up intermediate files
    rm -f ${prefix}.paf.gz ${prefix}.split ${prefix}.split.self.paf.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        purge_dups: \$(purge_dups --version 2>&1 | head -n1 | sed 's/purge_dups //')
        minimap2: \$(minimap2 --version 2>&1)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_purged.fa
    touch ${prefix}_haplotigs.fa
    touch ${prefix}_dups.bed
    touch PB.base.cov
    touch cutoffs
    touch ${prefix}_summary.txt
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        purge_dups: stub
        minimap2: stub
    END_VERSIONS
    """
}
