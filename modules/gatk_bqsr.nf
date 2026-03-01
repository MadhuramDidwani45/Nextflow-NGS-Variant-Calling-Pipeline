process BQSR {

    tag "$sample"

    publishDir "${params.alignment_dir}", mode: 'copy'

    input:
    tuple val(sample), path(bam), path(bai)
    tuple path(reference), path(ref_fai), path(ref_dict)   
    path known_sites
    path known_sites_index

    output:
    tuple val(sample), path(bam), path(bai), path("${sample}.recal.table")

    script:
    """
    gatk BaseRecalibrator \
        -R ${reference} \
        -I ${bam} \
        --known-sites ${known_sites} \
        -O ${sample}.recal.table
    """
}