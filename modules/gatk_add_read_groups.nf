process ADD_READ_GROUPS {

    tag "$sample"

    publishDir "${params.alignment_dir}", mode: 'copy'

    input:
    tuple val(sample), path(bam), path(bai)

    output:
    tuple val(sample), path("${sample}.rg.bam"), path("${sample}.rg.bam.bai")

    script:
    """
    gatk AddOrReplaceReadGroups \
        -I ${bam} \
        -O ${sample}.rg.bam \
        --RGID ${sample} \
        --RGLB lib1 \
        --RGPL ILLUMINA \
        --RGPU unit1 \
        --RGSM ${sample}

    samtools index ${sample}.rg.bam
    """
}