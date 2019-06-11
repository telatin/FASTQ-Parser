use strict;
use warnings;
use FindBin qw($Bin);
use Test::More;

use FASTX::Reader;

my $basename = "$Bin/../data/test.";

# Check that format returned equals the extension

for my $format ('fasta', 'fastq') {
    my $file = $basename . $format;

    # Check required input file
    if (! -e "$file") {
      print STDERR "Skip test: $file not found\n";
      next;
    }
    my $detected_format = FASTX::Reader->getFileFormat("$file");
    ok($format eq $detected_format, "Format detection ok for $format");


}
# Unknown formats are returned as 'undef': try with this perl script
my $detected_format = FASTX::Reader->getFileFormat("$0");
ok(! defined $detected_format, "Format detection ok: undef for non sequence file");

# bad.fastq is a fastq file with errors
my $bad_fastq = FASTX::Reader->getFileFormat("$Bin/../data/bad.fastq");
ok(! defined $detected_format, "Format detection ok: undef for bad FASTQ file");

done_testing();
