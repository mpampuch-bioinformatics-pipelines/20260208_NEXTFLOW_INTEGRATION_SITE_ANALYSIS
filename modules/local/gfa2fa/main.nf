process GFA2FA {
    tag "$meta.id"
    label 'process_low'

    conda "conda-forge::gawk=5.1.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/gawk:5.1.0' :
        'biocontainers/gawk:5.1.0' }"

    input:
    tuple val(meta), path(gfa)

    output:
    tuple val(meta), path("*.fa"), emit: fasta
    path "versions.yml"          , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def gfa_basename = gfa.baseName
    """
    awk '/^S/{print ">"\$2"\\n"\$3}' ${gfa} > ${gfa_basename}.fa

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gawk: \$(awk --version | head -n1 | sed 's/^GNU Awk //; s/,.*//')
    END_VERSIONS
    """

    stub:
    def gfa_basename = gfa.baseName
    """
    touch ${gfa_basename}.fa

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gawk: \$(awk --version | head -n1 | sed 's/^GNU Awk //; s/,.*//')
    END_VERSIONS
    """
}
