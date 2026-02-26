process TRIMM{
    tag "$sample"

    publishDir("$params.trimmed_reads", mode: 'copy')

    input:
    tuple val(sample), path(reads)

    output:
    tuple val(sample),path("${sample}_*.fastq.gz")

    script:
    def (read1,read2) = reads
    """
    echo "Trimmomatic of ${sample}"

    trimmomatic PE\
    ${read1} ${read2} \
    ${sample}_1_paired.fastq.gz ${sample}_1_unpaired.fastq.gz \
    ${sample}_2_paired.fastq.gz ${sample}_2_unpaired.fastq.gz \
    ILLUMINACLIP:NexteraPE-PE.fa:2:30:10 \
    LEADING:3 TRAILING:3 SLIDINGWINDOW:4:15 MINLEN:50
    """
}