process VARIANT_ANNOTATOR {

    tag "$sample"

    publishDir "${params.alignment_dir}", mode: 'copy'

    input:
    tuple val(sample), path(vcf), path(bam), path(bai)
    tuple path(reference), path(ref_fai), path(ref_dict)

    output:
    tuple val(sample), path("${sample}.annotated.vcf")

    script:
    """
    gatk VariantAnnotator \\
        -R ${reference} \\
        -V ${vcf} \\
        -I ${bam} \\
        -O ${sample}.annotated.vcf \\
        -A Coverage \\
        -A QualByDepth \\
        -A MappingQualityRankSumTest
    """
}