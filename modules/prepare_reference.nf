process PREPARE_REFERENCE {

    tag "Reference"

    publishDir "${params.index_dir}", mode: 'copy'

    input:
    path reference

    output:
    tuple path(reference), path("${reference}.fai"), path("${reference.baseName}.dict")

    script:
    """
    samtools faidx ${reference}
    gatk CreateSequenceDictionary -R ${reference}
    """
}