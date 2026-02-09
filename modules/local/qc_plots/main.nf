process QC_PLOTS {
    tag "${meta.id}"
    label 'process_low'

    container 'quay.io/biocontainers/python:3.11'

    input:
    tuple val(meta), path(paf)
    path(integration_sites)

    output:
    tuple val(meta), path('*.png'), emit: plots
    path 'versions.yml', emit: versions

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    #!/usr/bin/env python3

    import sys
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    from collections import defaultdict

    # Parse PAF file
    alignments = []
    with open('${paf}', 'r') as f:
        for line in f:
            if line.startswith('#'):
                continue
            fields = line.strip().split('\\t')
            if len(fields) < 11:
                continue
            alignments.append({
                'qname': fields[0],
                'qlen': int(fields[1]),
                'qstart': int(fields[2]),
                'qend': int(fields[3]),
                'strand': fields[4],
                'tname': fields[5],
                'tlen': int(fields[6]),
                'tstart': int(fields[7]),
                'tend': int(fields[8]),
                'matches': int(fields[9]),
                'alnlen': int(fields[10]),
                'mapq': int(fields[11])
            })

    # Parse integration sites
    sites = []
    with open('${integration_sites}', 'r') as f:
        for line in f:
            if line.startswith('#'):
                continue
            parts = line.strip().split('\\t')
            if len(parts) >= 2:
                sites.append({'chr': parts[0], 'pos': int(parts[1])})

    # Plot 1: Alignment length distribution
    fig, ax = plt.subplots(figsize=(10, 6))
    lengths = [aln['alnlen'] for aln in alignments]
    if lengths:
        ax.hist(lengths, bins=50, edgecolor='black')
        ax.set_xlabel('Alignment Length (bp)')
        ax.set_ylabel('Count')
        ax.set_title('Distribution of Alignment Lengths')
        plt.tight_layout()
        plt.savefig('${prefix}_alignment_lengths.png', dpi=300)
        plt.close()

    # Plot 2: Mapping quality distribution
    fig, ax = plt.subplots(figsize=(10, 6))
    mapqs = [aln['mapq'] for aln in alignments]
    if mapqs:
        ax.hist(mapqs, bins=50, edgecolor='black')
        ax.set_xlabel('Mapping Quality')
        ax.set_ylabel('Count')
        ax.set_title('Distribution of Mapping Quality Scores')
        plt.tight_layout()
        plt.savefig('${prefix}_mapping_quality.png', dpi=300)
        plt.close()

    # Plot 3: Integration sites per chromosome
    fig, ax = plt.subplots(figsize=(12, 6))
    chr_counts = defaultdict(int)
    for site in sites:
        chr_counts[site['chr']] += 1
    
    if chr_counts:
        chrs = sorted(chr_counts.keys())
        counts = [chr_counts[c] for c in chrs]
        ax.bar(range(len(chrs)), counts, edgecolor='black')
        ax.set_xticks(range(len(chrs)))
        ax.set_xticklabels(chrs, rotation=45, ha='right')
        ax.set_xlabel('Chromosome')
        ax.set_ylabel('Number of Integration Sites')
        ax.set_title('Integration Sites per Chromosome')
        plt.tight_layout()
        plt.savefig('${prefix}_sites_per_chr.png', dpi=300)
        plt.close()

    # Write versions
    with open('versions.yml', 'w') as f:
        f.write('"${task.process}":\\n')
        f.write('    python: ' + sys.version.split()[0] + '\\n')
        f.write('    matplotlib: ' + matplotlib.__version__ + '\\n')
    """
}
