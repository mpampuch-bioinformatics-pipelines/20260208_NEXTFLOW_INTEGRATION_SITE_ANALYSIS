# HiFiASM Assembly Implementation

This document describes the implementation of the HiFiASM genome assembly step in the Nextflow pipeline, which replaces the SLURM-based `step2_run_assemblies.sbatch` script.

## Overview

The assembly step uses HiFiASM to perform genome assembly from PacBio HiFi reads, with automatic conversion of GFA output to FASTA format.

## Implementation Components

### 1. Modules

#### HiFiASM Module (`modules/nf-core/hifiasm/main.nf`)
- **Source**: nf-core modules (pre-existing)
- **Function**: Performs genome assembly using HiFiASM
- **Inputs**: 
  - HiFi reads (FASTQ format)
  - Optional: Ultra-long reads, Hi-C reads, parental k-mer dumps
- **Outputs**:
  - Primary contigs (`.p_ctg.gfa`)
  - Alternate contigs (`.a_ctg.gfa`)
  - Raw unitigs (`.r_utg.gfa`)
  - Processed unitigs (`.p_utg.gfa`)
  - Binary files (`.bin`) for resuming
  - Assembly log (`.stderr.log`)

#### GFA2FA Module (`modules/local/gfa2fa/main.nf`)
- **Source**: Custom local module
- **Function**: Converts GFA format to FASTA format
- **Implementation**: Uses AWK to parse GFA and extract sequences
- **Inputs**: GFA file
- **Outputs**: FASTA file

### 2. Subworkflow

#### Assembly Subworkflow (`subworkflows/local/assembly/main.nf`)
- **Function**: Orchestrates the assembly process
- **Process Flow**:
  1. Run HiFiASM on input reads
  2. Convert primary contigs GFA to FASTA
  3. Convert alternate contigs GFA to FASTA
  4. Collect and emit all outputs

### 3. Configuration

#### Resource Allocation (`CONF/base.config`)
Added custom `assembly` label with resources matching the SLURM script:
```groovy
withLabel:assembly {
    cpus   = { 32     * task.attempt }
    memory = { 128.GB * task.attempt }
    time   = { 24.h   * task.attempt }
}
```

#### Module Configuration (`CONF/modules.config`)
```groovy
withName: 'HIFIASM' {
    label      = 'assembly'
    ext.args   = '--primary'
    publishDir = [
        [
            path: { "${params.outdir}/assemblies/${meta.id}" },
            mode: params.publish_dir_mode,
            pattern: "*.gfa"
        ],
        [
            path: { "${params.outdir}/assemblies/${meta.id}/logs" },
            mode: params.publish_dir_mode,
            pattern: "*.stderr.log"
        ],
        [
            path: { "${params.outdir}/assemblies/${meta.id}/bin" },
            mode: params.publish_dir_mode,
            pattern: "*.bin",
            enabled: false
        ]
    ]
}

withName: 'GFA2FA' {
    publishDir = [
        path: { "${params.outdir}/assemblies/${meta.id}/fasta" },
        mode: params.publish_dir_mode,
        pattern: "*.fa"
    ]
}
```

### 4. Pipeline Integration

The assembly subworkflow is integrated into the main pipeline (`workflows/pipeline.nf`):

```groovy
include { ASSEMBLY } from '../subworkflows/local/assembly/main'

workflow PIPELINE {
    take:
    ch_samplesheet

    main:
    ASSEMBLY(ch_samplesheet)
    
    emit:
    primary_assemblies   = ASSEMBLY.out.primary_fasta
    alternate_assemblies = ASSEMBLY.out.alternate_fasta
    assembly_logs        = ASSEMBLY.out.assembly_log
}
```

## Comparison with SLURM Script

| Feature | SLURM Script | Nextflow Implementation |
|---------|--------------|------------------------|
| **Parallelization** | SLURM array jobs (1-12) | Automatic per-sample parallelization |
| **Resource Management** | Fixed allocation (32 CPUs, 128GB) | Dynamic with retry on failure |
| **Output Format** | Manual GFA → FASTA conversion | Automatic conversion via module |
| **Resumability** | Must rerun entire array | Resume from any failed sample |
| **Error Handling** | Manual checking | Automatic retry with increased resources |
| **Portability** | SLURM-specific | Runs on any executor (SLURM, AWS, local, etc.) |
| **Scalability** | Limited to array size | Automatically scales with input |

## Output Structure

```
${params.outdir}/
├── assemblies/
│   ├── sample1/
│   │   ├── sample1.p_ctg.gfa      # Primary contigs GFA
│   │   ├── sample1.a_ctg.gfa      # Alternate contigs GFA
│   │   ├── fasta/
│   │   │   ├── sample1.p_ctg.fa   # Primary contigs FASTA
│   │   │   └── sample1.a_ctg.fa   # Alternate contigs FASTA
│   │   └── logs/
│   │       └── sample1.stderr.log # Assembly log
│   ├── sample2/
│   │   └── ...
│   └── ...
└── pipeline_info/
    ├── execution_timeline.html
    ├── execution_report.html
    └── execution_trace.txt
```

## Running the Pipeline

### Basic Usage

```bash
# Load environment (on HPC)
source env.sh

# Run the pipeline
nextflow run main.nf \
  -profile singularity \
  --input samplesheet.csv \
  --outdir OUTPUTS
```

### With Custom Parameters

```bash
nextflow run main.nf \
  -profile singularity \
  --input samplesheet.csv \
  --outdir OUTPUTS \
  -resume  # Resume from previous run
```

### On SLURM Cluster

```bash
nextflow run main.nf \
  -profile singularity \
  --input samplesheet.csv \
  --outdir OUTPUTS \
  -with-tower  # Optional: monitor with Seqera Platform
```

## Samplesheet Format

The pipeline expects a CSV samplesheet with the following format:

```csv
strain,reads
sample1,/path/to/sample1.fastq
sample2,/path/to/sample2.fastq
```

## Advanced Configuration

### Customizing HiFiASM Arguments

Add custom HiFiASM arguments in `CONF/modules.config`:

```groovy
withName: 'HIFIASM' {
    ext.args   = '--primary -l 3 -s 0.55'  // Example: adjust purging level and similarity
}
```

### Resource Adjustment

Modify resources in `CONF/base.config`:

```groovy
withLabel:assembly {
    cpus   = { 64     * task.attempt }  // Increase to 64 CPUs
    memory = { 256.GB * task.attempt }  // Increase to 256GB
    time   = { 48.h   * task.attempt }  // Increase to 48 hours
}
```

## Benefits of Nextflow Implementation

1. **Automatic Parallelization**: Processes all samples in parallel based on available resources
2. **Resume Capability**: Failed samples can be rerun without reprocessing successful ones
3. **Resource Optimization**: Dynamic resource allocation with automatic retry
4. **Portability**: Same workflow runs on local, HPC, cloud (AWS, GCP, Azure)
5. **Monitoring**: Integration with Seqera Platform for real-time monitoring
6. **Reproducibility**: Complete software versioning and provenance tracking
7. **Error Recovery**: Automatic retry with increased resources on failure

## Troubleshooting

### Out of Memory Errors
- Increase memory in `CONF/base.config` under the `assembly` label
- Check HiFi read quality and consider filtering low-quality reads

### Slow Assembly
- Verify sufficient CPUs are allocated
- Check if input files are in compressed format (slower I/O)
- Consider using local scratch storage for temporary files

### Missing Outputs
- Check the log files in `assemblies/${sample_id}/logs/`
- Review the Nextflow execution report: `${params.outdir}/pipeline_info/execution_report.html`
- Enable debug mode: `nextflow run main.nf -profile singularity,debug`

## Next Steps

After assembly completion, the FASTA files can be used for:
1. Assembly quality assessment (step2-1: Harr plots)
2. Duplicate purging (step2-2: purge_dups)
3. Sequence extraction (step2-3: dotplots)
4. BLAST analysis (step3-4: create BLAST database and run searches)
5. Region of interest extraction (step5)

## References

- HiFiASM: https://github.com/chhylp123/hifiasm
- Nextflow: https://www.nextflow.io/
- nf-core: https://nf-co.re/
- Seqera Platform: https://seqera.io/
