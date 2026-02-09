process MINIMAP2_ALIGN {
    tag "${meta.id}"
    label 'process_medium'

    container "${workflow.containerEngine == 'singularity' ? 'https://depot.galaxyproject.org/singularity/minimap2:2.28--he4a0461_2' : 'quay.io/biocontainers/minimap2:2.28--he4a0461_2'}"

    input:
    tuple val(meta), path(reference)
    path(query)

    output:
    tuple val(meta), path('*.paf'), emit: paf
    path 'versions.yml', emit: versions

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    minimap2 \\
        -t ${task.cpus} \\
        ${args} \\
        ${reference} \\
        ${query} \\
        > ${prefix}.paf

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        minimap2: \$(minimap2 --version 2>&1)
    END_VERSIONS
    """
}
