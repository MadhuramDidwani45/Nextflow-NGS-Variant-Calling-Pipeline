process HAPLOTYPECALLER {

    tag "$sample"

    publishDir "${params.alignment_dir}", mode: 'copy'

    input:
    tuple val(sample), path(bam), path(bai)
    tuple path(reference), path(ref_fai), path(ref_dict)

    output:
    tuple val(sample), path("${sample}.vcf")

    script:
    """
    gatk HaplotypeCaller \\
        -R ${reference} \\
        -I ${bam} \\
        -O ${sample}.vcf
    """
}