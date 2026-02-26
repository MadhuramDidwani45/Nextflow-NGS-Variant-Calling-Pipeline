include {FASTQ_DUMP} from './modules/fastq_dump'
include {FASTQC} from './modules/fastqc'
include {TRIMM} from './modules/trimmomatic'

workflow{

    sample_ch = channel.fromPath("$params.sample")
    FASTQ_DUMP(sample_ch)
    reads_ch = channel.fromFilePairs("$params.reads")
    FASTQC(reads_ch)
    TRIMM(reads_ch)
}