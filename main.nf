include {FASTQ_DUMP} from './modules/fastq_dump'

workflow{

    sample_ch = channel.fromPath("$params.sample")
    FASTQ_DUMP(sample_ch)
}