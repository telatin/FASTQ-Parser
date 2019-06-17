use strict;
use warnings;
use FindBin qw($Bin);
use Test::More tests => 2;

# This test checks the loadability of the module
# and that the object is correctly blessed as FASTX::Reader

use_ok 'FASTX::Reader';
my $seq = "$Bin/../data/test.fastq";

#SKIP if seq not found, but expects 2 test
SKIP: {
    skip "$seq not found\n", 1 if (! -e "$seq");
    my $data = FASTX::Reader->new({ filename => "$seq" });
    isa_ok($data, 'FASTX::Reader');
}