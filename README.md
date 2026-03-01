## Overview

This pipeline performs end-to-end germline variant calling starting from an SRA accession number (`.sra` file) and producing annotated VCF output. It is built with **Nextflow DSL2**, using modular process definitions and supports `-resume` for efficient re-runs.

---

## Workflow

![Workflow Diagram](workflow.svg)

The pipeline is organised into five stages shown above:

| Stage | Colour | Steps |
|-------|--------|-------|
| ① Quality Control | 🟡 Yellow | FASTQ_DUMP → FASTQC → TRIMM → TRIMMED_FASTQC |
| ② Reference & Alignment | 🔵 Blue | PREPARE_REFERENCE → BOWTIE2_INDEX → BOWTIE2_ALIGN |
| ③ Pre-processing | 🟢 Green | SAMTOOLS → ADD_READ_GROUPS → MARK_DUPLICATES |
| ④ BQSR | 🟣 Purple | BQSR (BaseRecalibrator) → APPLY_BQSR |
| ⑤ Variant Calling | 🟠 Orange | HAPLOTYPECALLER → VARIANT_FILTRATION → VARIANT_ANNOTATOR |

---

## Quick Start

### 1. Install Nextflow

```bash
curl -s https://get.nextflow.io | bash
mv nextflow ~/bin/
```

### 2. Clone the repository

```bash
git clone https://github.com/<your-username>/nf-pipeline-variantcall.git
cd nf-pipeline-variantcall
```

### 3. Set up your reference files

```
Ref/
├── Human/
│   └── Reference_genome.fa          # GRCh38, UCSC chr-style naming
└── Mills_and_1000G_gold_standard.indels.hg38.vcf.gz
    Mills_and_1000G_gold_standard.indels.hg38.vcf.gz.tbi
```

> **Important:** The reference genome must use UCSC-style chromosome names (`chr1`, `chr2`, ...) to match the Mills VCF. Download the recommended reference:
> ```bash
> wget https://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/000/001/405/GCA_000001405.15_GRCh38/seqs_for_alignment_pipelines.ucsc_ids/GCA_000001405.15_GRCh38_no_alt_analysis_set.fna.gz
> gunzip GCA_000001405.15_GRCh38_no_alt_analysis_set.fna.gz
> mv GCA_000001405.15_GRCh38_no_alt_analysis_set.fna Ref/Human/Reference_genome.fa
> ```

### 4. Place your SRA file

```
data/
└── ERR13985875.sra
```

### 5. Run

```bash
# Full run
nextflow run main.nf

# Resume from cached steps
nextflow run main.nf -resume

# With custom config
nextflow run main.nf -c custom.config -resume
```

---

## Pipeline Steps

### ① Quality Control

#### `FASTQ_DUMP` — SRA Toolkit
Converts `.sra` files to paired-end gzipped FASTQ files.
```
fastq-dump --split-files --gzip <sample.sra>
```

#### `FASTQC` — FastQC
Quality assessment of raw reads. HTML and ZIP reports are saved to `results/Fastqc/Before/`.

#### `TRIMM` — Trimmomatic
Removes adapters and low-quality bases in paired-end mode. Only paired output reads continue downstream.
```
ILLUMINACLIP:NexteraPE-PE.fa:2:30:10 LEADING:3 TRAILING:3 SLIDINGWINDOW:4:15 MINLEN:50
```

#### `TRIMMED_FASTQC` — FastQC
Post-trimming quality check saved to `results/Fastqc/After/`.

---

### ② Reference & Alignment

#### `PREPARE_REFERENCE` — SAMtools + GATK
Generates the FASTA index (`.fai`) and sequence dictionary (`.dict`) required by all GATK tools. Runs once; output is shared across all GATK processes via `channel.value()`.

#### `BOWTIE2_INDEX` — Bowtie2
Builds the Bowtie2 alignment index from the reference FASTA. Stored in `Ref/Human/index/`.

> Building the full GRCh38 index takes ~60–90 minutes and requires ~8 GB RAM — expected behaviour, not a crash.

#### `BOWTIE2_ALIGN` — Bowtie2
Aligns trimmed paired-end reads to the reference. Unaligned reads are discarded (`--no-unal`).
```
bowtie2 --no-unal -p <cpus> -x <index> -1 <r1> -2 <r2> -S <sample>.sam
```

---

### ③ Pre-processing

#### `SAMTOOLS` — SAMtools
Converts SAM to BAM, sorts by coordinate, and indexes.
```
samtools view -Sb → samtools sort → samtools index
```

#### `ADD_READ_GROUPS` — GATK AddOrReplaceReadGroups
Embeds read group metadata (RGID, RGLB, RGPL, RGPU, RGSM) required by GATK variant callers.

#### `MARK_DUPLICATES` — GATK MarkDuplicates
Flags PCR and optical duplicate reads to prevent inflation of variant allele frequencies. Outputs a metrics file alongside the marked BAM.

---

### ④ Base Quality Score Recalibration (BQSR)

#### `BQSR` — GATK BaseRecalibrator
Models systematic base quality errors using known variant sites (Mills & 1000G). Outputs a recalibration table.
```
gatk BaseRecalibrator -R <ref> -I <bam> --known-sites <mills.vcf.gz> -O <sample>.recal.table
```

#### `APPLY_BQSR` — GATK ApplyBQSR
Applies the recalibration table to produce a corrected BAM with adjusted base quality scores.
```
gatk ApplyBQSR -R <ref> -I <bam> --bqsr-recal-file <recal.table> -O <sample>.recalibrated.bam
```

---

### ⑤ Variant Calling & Annotation

#### `HAPLOTYPECALLER` — GATK HaplotypeCaller
Calls SNPs and short indels via local de-novo haplotype assembly.
```
gatk HaplotypeCaller -R <ref> -I <recalibrated.bam> -O <sample>.vcf
```

#### `VARIANT_FILTRATION` — GATK VariantFiltration
Tags low-confidence variants with soft filters. Variants are **flagged, not removed**.

| Filter | Expression | Rationale |
|--------|------------|-----------|
| `LowQD` | `QD < 2.0` | Low quality normalised by depth |
| `HighFS` | `FS > 60.0` | Excessive strand bias |

#### `VARIANT_ANNOTATOR` — GATK VariantAnnotator
Adds per-variant annotations from the recalibrated BAM to support prioritisation and interpretation.

| Annotation | Description |
|------------|-------------|
| `Coverage` | Total read depth at each site |
| `QualByDepth` | Variant quality normalised by depth |
| `MappingQualityRankSumTest` | MQ difference between ref and alt reads |

---

## Repository Structure

```
.
├── main.nf                        # Workflow entry point
├── nextflow.config                # Parameters and resource profiles
├── modules/
│   ├── fastq_dump.nf
│   ├── fastqc.nf
│   ├── trimmomatic.nf
│   ├── trimmed_fastqc.nf
│   ├── prepare_reference.nf
│   ├── bowtie2_index.nf
│   ├── bowtie2_align.nf
│   ├── samtools.nf
│   ├── gatk_add_read_groups.nf
│   ├── gatk_markduplicates.nf
│   ├── gatk_bqsr.nf
│   ├── gatk_applybqsr.nf
│   ├── gatk_haplotypecaller.nf
│   ├── gatk_variantfiltration.nf
│   └── gatk_variantannotator.nf
├── data/
│   └── *.sra
├── Ref/
│   ├── Human/
│   │   └── Reference_genome.fa
│   ├── Mills_and_1000G_gold_standard.indels.hg38.vcf.gz
│   └── Mills_and_1000G_gold_standard.indels.hg38.vcf.gz.tbi
└── results/
    ├── Fastqc/
    │   ├── Before/
    │   └── After/
    └── ...
```

---

## Configuration

**`nextflow.config`**

```groovy
params {
    sample                = "data/*.sra"
    reads                 = "reads/*_{1,2}.fastq.gz"
    fastqc_result         = "results/Fastqc/Before"
    trimmed_reads         = "reads/trimmed"
    trimmed_fastqc_result = "results/Fastqc/After"
    reference_genome      = "Ref/Human/Reference_genome.fa"
    index_dir             = "Ref/Human/index"
    alignment_dir         = "results/"
    known_sites           = "Ref/Mills_and_1000G_gold_standard.indels.hg38.vcf.gz"
    known_sites_index     = "Ref/Mills_and_1000G_gold_standard.indels.hg38.vcf.gz.tbi"
}

profiles {
    standard {
        process.cpus   = 4
        process.memory = '4 GB'
    }
}
```

---

## Output Files

| File | Description |
|------|-------------|
| `results/Fastqc/Before/*.html` | Raw read QC reports |
| `results/Fastqc/After/*.html` | Post-trimming QC reports |
| `results/<sample>.sorted.bam` | Coordinate-sorted BAM |
| `results/<sample>.markdup.bam` | Duplicate-marked BAM |
| `results/<sample>.recalibrated.bam` | BQSR-corrected BAM |
| `results/<sample>.vcf` | Raw variant calls |
| `results/<sample>.filtered.vcf` | Soft-filtered VCF |
| `results/<sample>.annotated.vcf` | Final annotated VCF |
| `results/<sample>.metrics.txt` | Duplicate metrics |
| `results/<sample>.recal.table` | BQSR recalibration table |

---

## Requirements

| Tool | Version |
|------|---------|
| Nextflow | ≥ 23.04.0 |
| SRA Toolkit | ≥ 3.0 |
| FastQC | ≥ 0.11 |
| Trimmomatic | ≥ 0.39 |
| Bowtie2 | ≥ 2.4 |
| SAMtools | ≥ 1.17 |
| GATK | ≥ 4.4 |
| Java | ≥ 17 |

---

## Troubleshooting

**`No overlapping contigs found` during BQSR**  
The reference genome and known sites VCF use different chromosome naming conventions. Your reference must use UCSC-style names (`chr1`, `chr2`, ...) to match the Mills VCF. See the reference setup instructions above.

**Bowtie2 index build takes very long**  
Expected. The full GRCh38 index requires ~1–2 hours. Use `-resume` so it is only built once.

**GATK process fails with `USER ERROR` on dictionary**  
Run `PREPARE_REFERENCE` (or clear its work directory) so the `.dict` file is regenerated from the new reference before rerunning.

---

## License

MIT License — see [LICENSE](LICENSE) for details.
