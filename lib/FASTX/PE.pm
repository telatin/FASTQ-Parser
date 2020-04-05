package FASTX::PE;
use 5.012;
use warnings;
use Carp qw(confess cluck);
use Data::Dumper;
use FASTX::Reader;
$FASTX::PE::VERSION = $FASTX::Reader::VERSION;
#ABSTRACT: A Paired-End FASTQ files reader, based on FASTX::Reader.


=head1 SYNOPSIS

  use FASTX::PE;
  my $filepath = '/path/to/assembly_R1.fastq';
  # Will automatically open "assembly_R2.fastq"
  my $fq_reader = FASTX::Reader->new({
    filename => "$filepath",
  });

  while (my $seq = $fasta_reader->getRead() ) {
    print $seq->{name}, "\t", $seq->{seq1}, "\t", $seq->{qual1}, "\n";
    print $seq->{name}, "\t", $seq->{seq2}, "\t", $seq->{qual2}, "\n";
  }

=head1 BUILD TEST

=for html <p><a href="https://travis-ci.org/telatin/FASTQ-Parser"><img src="https://travis-ci.org/telatin/FASTQ-Parser.svg?branch=master"></a></p>

Each GitHub release of the module is tested by L<Travis-CI|https://travis-ci.org/telatin/FASTQ-Parser/builds> using multiple Perl versions (5.14 to 5.28).

In addition to this, every CPAN release is tested by the L<CPAN testers grid|http://matrix.cpantesters.org/?dist=FASTX-Reader>.

=head1 METHODS


=head2 new()

Initialize a new FASTX::Reader object passing 'B<filename>' argument for the first pairend,
and optionally 'B<rev>' for the second (otherwise can be guessed substituting 'R1' with 'R2' and
'_1.' with '_2.')

  my $pairend = FASTX::Reader->({ 
      filename => "$file_R1",
      rev      => "$file_R2"
  });

To read from STDIN either pass C<{{STDIN}}> as filename, or don't pass a filename at all.
In this case the module will expect an interleaved pairedend file.

  my $seq_from_stdin = FASTX::Reader->();

If a '_R2' file is not found, the module will try parsing as B<interleaved>. This can be forced with:

  my $seq_from_file = FASTX::Reader->({
    filename    => "$file",
    interleaved => 1,
  });

=cut

sub new {

    # Instantiate object
    my ($class, $args) = @_;

    my %accepted_parameters = (
      'filename' => 1,
      'tag1' => 1,
      'tag2' => 1,
      'rev' => 1,
      'interleaved' => 1,
      'nocheck' => 1,
      'revcompl' => 1,
    );

    my $valid_attributes = join(', ', keys %accepted_parameters);

    if ($args) {
      for my $parameter (keys %{ $args} ) {
        confess("Attribute <$parameter> is not expected. Valid attributes are: $valid_attributes\n")
          if (! $accepted_parameters{$parameter} );
      }
    } else {
      $args->{filename} = '{{STDIN}}';
    }

    my $self = {
        filename    => $args->{filename},
        rev         => $args->{rev},
        interleaved => $args->{interleaved} // 0,
        tag1        => $args->{tag1},
        tag2        => $args->{tag2},
        nocheck     => $args->{nocheck} // 0,
        revcompl    => $args->{revcompl} // 0,
    };


    my $object = bless $self, $class;

    # Required to read STDIN?
    if ($self->{filename} eq '{{STDIN}}' or not $self->{filename}) {
      $self->{interleaved} = 1;
      $self->{stdin} = 1;
    }

    if ($self->{interleaved}) {
      # Decode interleaved
      if ($self->{stdin}) {
        $self->{R1} = FASTX::Reader->new({ filename => '{{STDIN}}' });
      } else {
        $self->{R1} = FASTX::Reader->new({ filename => "$self->{filename}"});
      }
    } else {
      # Decode PE
      if ( ! defined $self->{rev} ) {

        # Auto calculate reverse (R2) filename
        my $rev = $self->{filename};
        if (defined $self->{tag1} and defined $self->{tag2}) {
          $rev =~s/$self->{tag1}/$self->{tag2}/;
        } else {

          $rev =~s/_R1/_R2/;
          $rev =~s/_1/_2/ if ($rev eq $self->{filename});
        }

        if (not -e $rev)  {
          # TO DEFINE: confess("ERROR: The rev file for '$self->{filename}' was not found in '$rev'\n");
          say STDERR "WARNING: Pair not specified and \"$rev\" not found for \"$self->{filename}\":\n trying parsing as interleaved.\n";
          $self->{interleaved} = 1;
          $self->{nocheck} = 0;
        } elsif ($self->{filename} eq $rev) {
          say STDERR "WARNING: Pair not specified for \"$self->{filename}\":\n trying parsing as interleaved.\n";
          $self->{interleaved} = 1;
          $self->{nocheck} = 0;
        } else {
          $self->{rev} = $rev;
        }

      }

      $self->{R1}  = FASTX::Reader->new({ filename => "$self->{filename}"});
      $self->{R2}  = FASTX::Reader->new({ filename => "$self->{rev}"}) 
        if (not $self->{interleaved});

    }


    return $object;
}

=head2 getReads()

Will return the next sequences in the FASTA / FASTQ file.
The returned object has these attributes:

=over 4

=item I<name>

header of the sequence (identifier)

=item I<comment1> and I<comment2> 

any string after the first whitespace in the header, for the first and second paired read respectively.

=item I<seq1> and I<seq2>

DNA sequence for the first and the second pair, respectively

=item I<qual1> and I<qual2> 

quality for the first and the second pair, respectively

=back

=cut


sub getReads {
  my $self   = shift;
  #my ($fh, $aux) = @_;
  #@<instrument>:<run number>:<flowcell ID>:<lane>:<tile>:<x-pos>:<y-pos>:<UMI> <read>:<is filtered>:<control number>:<index>
  my $pe;
  my $r1;
  my $r2;

  if ($self->{interleaved}) {
    $r1 = $self->{R1}->getRead();
    $r2 = $self->{R1}->getRead();
  } else {
    $r1 = $self->{R1}->getRead();
    $r2 = $self->{R2}->getRead();
  }

  if (! defined $r1->{name} or !defined $r2->{name}) {
    return undef;
  }

  if (not defined $self->{nocheck}) {
    if ($r1->{name} ne  $r2->{name}) {
      confess("Read name different in PE:\n[$r1->{name}] !=\n[$r2->{name}]\n");
    }
  }

  $pe->{name} = $r1->{name};
  $pe->{seq1} = $r1->{seq};
  $pe->{qual1} = $r1->{qual};

  if ($self->{revcompl}) {
    $pe->{seq2} = _rc( $r2->{seq} );
    $pe->{qual2} = reverse( $r2->{qual} );
  } else {
    $pe->{seq2} = $r2->{seq};
    $pe->{qual2} = $r2->{qual};
  }

  $pe->{comment1} = $r1->{comment};
  $pe->{comment2} = $r2->{comment};

  return $pe;

}




=head1 SEE ALSO

=over 4

=item L<FASTX::Reader>

The FASTA/FASTQ parser this module is based on.

=back

=cut

sub _rc {
  my $sequence = shift @_;
  $sequence = reverse($sequence);
  $sequence =~tr/ACGTacgt/TGCAtgca/;
  return $sequence;
}
1;

