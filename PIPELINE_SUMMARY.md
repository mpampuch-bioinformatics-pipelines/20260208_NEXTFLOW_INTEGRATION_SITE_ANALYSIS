# Integration Site Analysis Pipeline

## Overview

This Nextflow DSL2 pipeline performs genome assembly and integration site detection analysis using HiFi reads. The pipeline follows strict syntax compliance (Nextflow v25.10+) and includes comprehensive quality control.

## Pipeline Workflow

```
HiFi Reads
    ↓
[HIFIASM] → Primary Assembly (GFA)
    ↓
[PURGE_DUPS] → Purged Assembly (FASTA)
    ↓
[MINIMAP2_ALIGN] → Alignment to Reference (PAF)
    ↓
[QC_PLOTS] → Quality Control Visualizations (PNG)
```

## Modules

### 1. HIFIASM
- **Purpose**: De novo assembly of HiFi reads
- **Input**: HiFi reads (FASTQ/FASTA)
- **Output**: Primary assembly in GFA format
- **Key Parameters**: 
  - `--primary` flag for primary contig generation
  - Configurable via `params.hifiasm_mode`

### 2. PURGE_DUPS
- **Purpose**: Remove haplotigs and duplicated contigs
- **Input**: Primary assembly (GFA) + HiFi reads
- **Output**: 
  - Purged assembly (FASTA)
  - Haplotigs (FASTA)
  - Duplication bed file
  - Coverage statistics
  - Summary report
- **Pipeline Steps**:
  1. Align reads to assembly (minimap2)
  2. Calculate coverage (pbcstat)
  3. Determine cutoffs (calcuts)
  4. Split assembly (split_fa)
  5. Self-alignment (minimap2)
  6. Purge duplicates (purge_dups)
  7. Extract sequences (get_seqs)

### 3. MINIMAP2_ALIGN
- **Purpose**: Align assembly to reference genome
- **Input**: Reference genome + Assembly
- **Output**: Alignment in PAF format
- **Preset**: asm5 (assembly-to-reference alignment)

### 4. QC_PLOTS
- **Purpose**: Generate quality control visualizations
- **Input**: PAF alignment + Integration sites file
- **Output**: Three PNG plots:
  1. **Alignment Length Distribution**: Histogram of alignment lengths
  2. **Mapping Quality Distribution**: Histogram of mapping quality scores
  3. **Integration Sites per Chromosome**: Bar chart of site distribution
- **Requirements**: Python 3.11, matplotlib

## Required Parameters

```bash
--hifi_reads          Path to HiFi reads (required)
--reference           Path to reference genome (required)
--integration_sites   Path to integration sites file (required, TSV format: chr\tpos)
--outdir              Output directory (default: ./results)
--sample_id           Sample identifier (default: sample)
```

## Optional Parameters

```bash
--hifiasm_mode           Hifiasm mode (default: hifi)
--purge_dups_cutoffs     Manual cutoffs (default: auto-calculate)
--minimap2_preset        Minimap2 preset (default: asm5)
--max_cpus               Maximum CPUs (default: 16)
--max_memory             Maximum memory (default: 128.GB)
--max_time               Maximum time (default: 240.h)
```

## Usage Examples

### Basic Usage
```bash
nextflow run main.nf \
  --hifi_reads reads.fastq.gz \
  --reference genome.fasta \
  --integration_sites sites.tsv \
  --sample_id MySample
```

### With Docker
```bash
nextflow run main.nf \
  -profile docker \
  --hifi_reads reads.fastq.gz \
  --reference genome.fasta \
  --integration_sites sites.tsv
```

### With Singularity
```bash
nextflow run main.nf \
  -profile singularity \
  --hifi_reads reads.fastq.gz \
  --reference genome.fasta \
  --integration_sites sites.tsv
```

### Test Profile (Reduced Resources)
```bash
nextflow run main.nf \
  -profile test \
  --hifi_reads reads.fastq.gz \
  --reference genome.fasta \
  --integration_sites sites.tsv
```

## Resource Requirements

### Process Labels

| Label | CPUs | Memory | Time |
|-------|------|--------|------|
| process_single | 1 | 6 GB | 4 h |
| process_low | 2 | 12 GB | 4 h |
| process_medium | 6 | 36 GB | 8 h |
| process_high | 12 | 72 GB | 16 h |
| process_long | - | - | 20 h |

### Module Resource Assignments

- **HIFIASM**: process_high (12 CPUs, 72 GB, 16 h)
- **PURGE_DUPS**: process_high (12 CPUs, 72 GB, 16 h)
- **MINIMAP2_ALIGN**: process_medium (6 CPUs, 36 GB, 8 h)
- **QC_PLOTS**: process_low (2 CPUs, 12 GB, 4 h)

## Output Structure

```
results/
├── hifiasm/
│   ├── sample.asm.bp.p_ctg.gfa
│   └── versions.yml
├── purge_dups/
│   ├── sample_purged.fa
│   ├── sample_haplotigs.fa
│   ├── sample_dups.bed
│   ├── PB.base.cov
│   ├── cutoffs
│   ├── sample_summary.txt
│   └── versions.yml
├── minimap2_align/
│   ├── sample.paf
│   └── versions.yml
└── qc_plots/
    ├── sample_alignment_lengths.png
    ├── sample_mapping_quality.png
    ├── sample_sites_per_chr.png
    └── versions.yml
```

## Integration Sites File Format

The integration sites file should be a tab-separated file with chromosome and position:

```
chr1    1234567
chr1    2345678
chr2    3456789
...
```

## Container Support

The pipeline supports three container engines:

1. **Docker**: `docker.enabled = true`
2. **Singularity**: `singularity.enabled = true`
3. **Conda**: `conda.enabled = true`

All modules use biocontainers images from:
- Galaxy Depot (Singularity)
- Quay.io/biocontainers (Docker)

## Profiles

### debug
- Enables hash dumping
- Shows hostname before each process
- Disables cleanup
- Enables process name validation

### conda
- Uses Conda environments
- Requires `environment.yml` files in module directories

### docker
- Uses Docker containers
- Runs containers as current user

### singularity
- Uses Singularity containers
- Auto-mounts paths

### test
- Reduced resource limits (2 CPUs, 6 GB, 6 h)
- For testing with small datasets

## Version Tracking

Each module generates a `versions.yml` file containing:
- Tool name
- Tool version

These are collected and can be used for reproducibility reporting.

## Error Handling

- **Retry Strategy**: Automatic retry for resource-related errors (143, 137, 104, 134, 139)
- **Max Retries**: 1 retry per process
- **Exit Codes**: Captured via `process.shell = ['/bin/bash', '-euo', 'pipefail']`

## Workflow Completion

Upon completion, the pipeline reports:
- Completion timestamp
- Execution status (OK/failed)
- Total duration

## Dependencies

### Core Tools
- Nextflow >= 25.04.0
- Hifiasm (assembly)
- purge_dups suite (pbcstat, calcuts, split_fa, purge_dups, get_seqs)
- minimap2 (alignment)
- Python 3.11 + matplotlib (plotting)

### Optional
- Docker or Singularity for containerization
- Conda for environment management

## Code Quality

✅ **Nextflow Lint**: All files pass linting with no errors or warnings
✅ **Strict Syntax**: Compliant with Nextflow v25.10+ strict syntax requirements
✅ **DSL2**: Modern Nextflow DSL2 syntax throughout

## Author

Generated by Seqera AI

## License

Not specified
