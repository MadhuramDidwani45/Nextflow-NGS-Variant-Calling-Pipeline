process APPLY_BQSR {

    tag "$sample"

    publishDir "${params.alignment_dir}", mode: 'copy'

    input:
    tuple val(sample), path(bam), path(bai), path(recal_table)
    tuple path(reference), path(ref_fai), path(ref_dict)

    output:
    tuple val(sample), path("${sample}.recalibrated.bam"), path("${sample}.recalibrated.bai")

    script:
    """
    gatk ApplyBQSR \\
        -R ${reference} \\
        -I ${bam} \\
        --bqsr-recal-file ${recal_table} \\
        -O ${sample}.recalibrated.bam
    """
}