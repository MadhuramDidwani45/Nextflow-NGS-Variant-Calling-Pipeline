process SAMTOOLS {

    tag "$sample"

    publishDir "${params.alignment_dir}", mode: 'copy'

    input:
    tuple val(sample), path(sam)

    output:
    tuple val(sample), path("${sample}.sorted.bam"), path("${sample}.sorted.bam.bai")

    script:
    """
    samtools view -Sb -o ${sample}.bam ${sam}
    samtools sort -O bam -o ${sample}.sorted.bam ${sample}.bam
    samtools index ${sample}.sorted.bam
    """
}