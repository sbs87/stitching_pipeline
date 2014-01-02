##step-by-step preprocessing miseq 300PE reads


#1. trim barcode

####trim barcode, form a new barcode file, this step requires fastx_trimmer from fastx toolbox
#Trim base 1-12 off each read file.
fastx_trimmer -i R1.fq -f 1 -l 12 -Q 33 -o R1_barcode.fq
fastx_trimmer -i R2.fq -f 1 -l 12 -Q 33 -o R2_barcode.fq

#fq_mergelines takes the four lines in a fastq file and pastes them tab delimited, one line per record
cat R1_barcode.fq | fq_mergelines.pl > R1_barcode_temp
cat R2_barcode.fq | fq_mergelines.pl > R2_barcode_temp
#5th col= header from (R2) $2=sequence (R1), $6=sequence(R2), $3=strand, $4=quality(R1), $8=quality(R2); split lines does reverse of mergelines 
paste R1_barcode_temp R2_barcode_temp | awk -F"\t" '{print $5"\t"$2$6"\t"$3"\t"$4$8}' | fq_splitlines.pl > R1R2_barcode.fastq

####trim barcode off the sequence
#This is opposite of above: takes read input and trims off first 12 bases, leaving only non barcode behind. 
seqtk trimfq -b 12 R1.fq > R1_trimmed_seq.fastq
seqtk trimfq -b 12 R2.fq > R2_trimmed_seq.fastq


#2. assemble paired end read using either pandaseq, FLASH, or SeqPrep. QIIME 1.8 version also implement the function of merging reads ends.

#a)using pandaseq, note that the overlapping length needed to be determined based on read length and amplicon size
#Run Pandaseq to assemble MiSeq1 paired-end reads
pandaseq -F -o $overlapping_length -B -f R1.fq -r R3.fq > PandaAssembly.fq

#Use a Perl script followed by a Python script to fix Pandaseq MiSeq1 output and prepare it for Qiime
touch fix_5742_pandaseq_fastq.pl
echo -e "0a\n\#\!/usr/bin/perl\n\nmy_SPACE_\$filename_SPACE_=_SPACE_<\$ARGV[0]>;\nchomp_SPACE_\$filename;\nopen_SPACE_(FASTQ,_SPACE_\$filename);\n\t{\n\tif_SPACE_(\$filename_SPACE_=~_SPACE_/(.*)\\.[^.]*/)\n\t\t{\n\t\topen_SPACE_OUT,_SPACE_\">\$1.fixed.fastq\";\n\t\t}\n\t}\n\nwhile_SPACE_(<FASTQ>)\n\t{\n\tif_SPACE_(\$__SPACE_=~_SPACE_/^\\\@(NGSC\\-005)\\:(\\d*)\\:(000000000\\-A14NC)\\:(\\d*)\\:(\\\d*)\\:(\\d*)\\:(\\d*)\\:/)\n\t\t{\n\t\tprint_SPACE_OUT_SPACE_\"\\\@\$1:\$2:\$3:\$4:\$5:\$6:\$7_SPACE_2:N:0:_SLASH__LETTERN_\";\n\t\t}\n\telse\n\t\t{\n\t\tprint_SPACE_OUT_SPACE_\$_;\n\t\t}\n\t}\n\n.\n,wq" | ed fix_5742_pandaseq_fastq.pl
sed -i 's/_SPACE_/ /g' fix_5742_pandaseq_fastq.pl
sed -i 's/_SLASH_/\\/g' fix_5742_pandaseq_fastq.pl
sed -i 's/_LETTERN_/n/g' fix_5742_pandaseq_fastq.pl
sed -i 's/\\\#\\\!/\#\!/g' fix_5742_pandaseq_fastq.pl

perl fix_5742_pandaseq_fastq.pl PandaAssembly.fq

##make a barcode file with only the entries associated with sequences in the Pandaseq assembled MiSeq1 data set
sed -n '1~4'p PandaAssembly.fixed.fastq | sed -e 's/^@//' -e 's/:$//' > PandaAssembly.keep.header
seqtk subseq R2.fq PandaAssembly.keep.header > R2_filter.fq

sed '1~4 s/:$//' PandaAssembly.fixed.fastq > assembly.fq

fastqc --nogroup --noextract -q assembly.fq

#b) using FLASH
# http://ccb.jhu.edu/software/FLASH/

#c) SeqPrep
# https://github.com/jstjohn/SeqPrep

#d) QIIME1.8 also have the assembly featuer
# join_paired_end.py


#3. match up the barcode and sequence file, script attached
fq_getPairAndOrphan1.8.py R3.fastq R1.fastq R3N_PE.fq R1N_PE.fq orphan_temp.fq
fq_getPairAndOrphan1.8.py R3N_PE.fq R1R2_barcode.fastq PE_temp.fq barcode.fq orphan_temp.fq

# Eventually assembly.fq barcode.fq are the 3 files that you want to use for split

#4. run split_library for illumina using QIIME
http://qiime.org/1.3.0/scripts/split_libraries_fastq.html

#5. post-processing to remove barcode, 
# first trim off barcode, which is 24 bases at the beginning of the sequences
# to trim stagger and primer, I use tagcleaner (http://tagcleaner.sourceforge.net) to trim off the sequences from the beginning of the reads to the part that could match to the primer.

#6. for 250PE, if need to stitch, using stitching_pipeline.pl
stitching_pipeline.pl -i R1_seqs.fasta -j R2_seqs.fasta -o output_dir
