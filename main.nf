#!/usr/bin/env nextflow

/*
========================================================================================
    Integration Site Analysis Pipeline
========================================================================================
    Genome Assembly and Integration Site Detection Pipeline
    
    This pipeline:
    1. Assembles HiFi reads using Hifiasm
    2. Purges haplotigs using purge_dups
    3. Aligns assemblies to reference genome
    4. Generates QC plots for integration site analysis
----------------------------------------------------------------------------------------
*/

nextflow.enable.dsl = 2

/*
========================================================================================
    NAMED WORKFLOW FOR PIPELINE
========================================================================================
*/

include { HIFIASM } from './modules/local/hifiasm/main'
include { PURGE_DUPS } from './modules/local/purge_dups/main'
include { MINIMAP2_ALIGN } from './modules/local/minimap2_align/main'
include { QC_PLOTS } from './modules/local/qc_plots/main'

workflow INTEGRATION_SITE_ANALYSIS {
    
    take:
    hifi_reads_ch     // channel: [ val(meta), path(reads) ]
    reference_ch      // channel: [ val(meta), path(reference) ]
    integration_sites // channel: path(sites)
    
    main:
    def ch_versions = channel.empty()
    
    //
    // MODULE: Hifiasm assembly
    //
    HIFIASM(hifi_reads_ch)
    ch_versions = ch_versions.mix(HIFIASM.out.versions)
    
    //
    // Combine assembly with reads for purge_dups
    //
    def purge_input = HIFIASM.out.primary_gfa.combine(hifi_reads_ch.map{ _m, r -> r })
    
    //
    // MODULE: Purge duplicate haplotigs
    //
    PURGE_DUPS(purge_input)
    ch_versions = ch_versions.mix(PURGE_DUPS.out.versions)
    
    //
    // MODULE: Align purged assembly to reference
    //
    MINIMAP2_ALIGN(
        reference_ch,
        PURGE_DUPS.out.purged_fa
    )
    ch_versions = ch_versions.mix(MINIMAP2_ALIGN.out.versions)
    
    //
    // MODULE: Generate QC plots
    //
    QC_PLOTS(
        MINIMAP2_ALIGN.out.paf,
        integration_sites
    )
    ch_versions = ch_versions.mix(QC_PLOTS.out.versions)
    
    emit:
    primary_gfa    = HIFIASM.out.primary_gfa
    purged_fasta   = PURGE_DUPS.out.purged_fa
    alignment_paf  = MINIMAP2_ALIGN.out.paf
    qc_plots       = QC_PLOTS.out.plots
    versions       = ch_versions
}

/*
========================================================================================
    RUN MAIN WORKFLOW
========================================================================================
*/

workflow {
    
    main:
    
    //
    // Parameter validation
    //
    if (!params.hifi_reads) {
        error "ERROR: --hifi_reads parameter is required"
    }
    if (!params.reference) {
        error "ERROR: --reference parameter is required"
    }
    if (!params.integration_sites) {
        error "ERROR: --integration_sites parameter is required"
    }
    
    //
    // Create input channels
    //
    def hifi_meta = [ id: params.sample_id ?: 'sample' ]
    def hifi_reads_ch = channel.of([hifi_meta, file(params.hifi_reads, checkIfExists: true)])
    
    def ref_meta = [ id: 'reference' ]
    def reference_ch = channel.of([ref_meta, file(params.reference, checkIfExists: true)])
    
    def integration_sites = file(params.integration_sites, checkIfExists: true)
    
    //
    // RUN PIPELINE
    //
    INTEGRATION_SITE_ANALYSIS(
        hifi_reads_ch,
        reference_ch,
        integration_sites
    )
    
    workflow.onComplete = {
        println "Pipeline completed at: ${workflow.complete}"
        println "Execution status: ${workflow.success ? 'OK' : 'failed'}"
        println "Duration: ${workflow.duration}"
    }
}
