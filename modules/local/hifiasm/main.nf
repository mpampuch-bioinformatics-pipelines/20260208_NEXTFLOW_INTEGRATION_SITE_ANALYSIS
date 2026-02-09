process HIFIASM {
    tag "$meta.id"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/hifiasm:0.19.8--h43eeafb_0':
        'biocontainers/hifiasm:0.19.8--h43eeafb_0' }"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*.p_ctg.gfa"), emit: primary_gfa
    tuple val(meta), path("*.a_ctg.gfa"), emit: alternate_gfa, optional: true
    tuple val(meta), path("*.p_utg.gfa"), emit: primary_unitigs, optional: true
    tuple val(meta), path("*.r_utg.gfa"), emit: reads_unitigs, optional: true
    tuple val(meta), path("*.ec.bin"), emit: corrected_reads, optional: true
    tuple val(meta), path("*.ovlp.*.bin"), emit: overlaps, optional: true
    tuple val(meta), path("*.log"), emit: log
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    # Run HiFiASM with primary mode
    hifiasm \\
        -o ${prefix} \\
        -t ${task.cpus} \\
        --primary \\
        ${args} \\
        ${reads} \\
        2>&1 | tee ${prefix}.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        hifiasm: \$(hifiasm --version 2>&1 | grep -oP 'hifiasm-\\K[0-9.]+' || echo "unknown")
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.p_ctg.gfa
    touch ${prefix}.a_ctg.gfa
    touch ${prefix}.log
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        hifiasm: stub
    END_VERSIONS
    """
}
