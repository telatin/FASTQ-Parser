package FASTX::Reader;
use 5.014;
use warnings;
use Carp qw(confess);

$FASTX::Reader::VERSION = '0.08';
#ABSTRACT: A lightweight module to parse FASTA and FASTQ files, based on Heng Li's readfq() method, packaged in an object oriented parser.

=head1 SYNOPSIS

  use FASTX::Reader;
  my $filepath = '/path/to/assembly.fastq';
  die "Input file not found: $filepath\n" unless (-e "$filepath");
  my $fasta_reader = FASTX::Reader->new({ filename => "$filepath" });

  while (my $seq = $fasta_reader->getRead() ) {
    print $seq->{name}, "\t", $seq->{seq}, "\t", $seq->{qual}, "\n";
  }

=head2 BUILD TEST

=for html <a href="https://travis-ci.org/telatin/FASTQ-Parser"><img src="https://travis-ci.org/telatin/FASTQ-Parser.svg?branch=master"></a>

=head1 METHODS


=head2 new()

Initialize a new FASTX::Reader object passing 'filename' argument. Will open a filehandle
stored as $object->{fh}.

  my $seq_from_file = FASTX::Reader->({ filename => "$file" });

To read from STDIN either pass C<{{STDIN}}> as filename, or don't pass a filename at all:

  my $seq_from_stdin = FASTX::Reader->();

=cut

sub new {
    # Instantiate object
    my ($class, $args) = @_;

    my $self = {
        filename  => $args->{filename},
    };

    my $object = bless $self, $class;

    # Initialize auxiliary array for getRead
    $object->{aux} = [undef];

    # Check if a filename was provided and not {{STDIN}}
    # uncoverable branch false
    if (defined $self->{filename} and $self->{filename} ne '{{STDIN}}') {
      open my $fh,  '<:encoding(UTF-8)', $self->{filename} or confess "Unable to read file ", $self->{filename}, ": ", $!, "\n";
      $object->{fh} = $fh;
    } else {
      $self->{fh} = \*STDIN;
    }

    return $object;
}

=head2 getRead()

Will return the next sequence in the FASTA / FASTQ file using Heng Li's implementation of the readfq() algorithm.
The returned object has these attributes:

=over 4

=item I<name>

header of the sequence (identifier)

=item I<comment>

any string after the first whitespace in the header

=item I<seq>

actual sequence

=item I<qual>

quality if the file is FASTQ

=back

=cut
sub getRead {
  my $self   = shift;
  #my ($fh, $aux) = @_;
  my $fh = $self->{fh};
  my $aux = $self->{aux};
  my $return;
  @$aux = [undef, 0] if (!(@$aux));	# remove deprecated 'defined'
  return if ($aux->[1]);
  # uncoverable branch true
  if (!defined($aux->[0])) {
      while (<$fh>) {
          chomp;
          if (substr($_, 0, 1) eq '>' || substr($_, 0, 1) eq '@') {
              $aux->[0] = $_;
              last;
          }
      }
      if (!defined($aux->[0])) {
          $aux->[1] = 1;
          return;
      }
  }
  my $name = /^.(\S+)/? $1 : '';
  my $comm = /^.\S+\s+(.*)/? $1 : ''; # retain "comment"
  my $seq = '';
  my $c;
  $aux->[0] = undef;
  while (<$fh>) {
      chomp;
      $c = substr($_, 0, 1);
      last if ($c eq '>' || $c eq '@' || $c eq '+');
      $seq .= $_;
  }
  $aux->[0] = $_;
  $aux->[1] = 1 if (!defined($aux->[0]));
  $return->{name} = $name;
  $return->{seq} = $seq;
  $self->{counter}++;
  return $return if ($c ne '+');
  my $qual = '';
  while (<$fh>) {
      chomp;
      $qual .= $_;
      if (length($qual) >= length($seq)) {
          $aux->[0] = undef;
          $return->{name} = $name;
          $return->{seq} = $seq;
          $return->{comment} = $comm;
          $return->{qual} = $qual;
          #$self->{counter}+=100;
          return $return;
      }
  }
  $aux->[1] = 1;
  $return->{name} = $name;
  $return->{seq} = $seq;
  $return->{comment} = $comm;
  $self->{counter}++;
  return $return;

}

=head2 getFastqRead()

If the file is FASTQ, this method returns the same read object as I<getRead()> but with a faster parser.
Attributes of the returned object are I<name>, I<comment>, I<seq>, I<qual> (as for I<getRead()>).

=cut

sub getFastqRead {
  my $self   = shift;
  my $seq_object = undef;
  my $header = readline($self->{fh});
  my $seq    = readline($self->{fh});
  my $check  = readline($self->{fh});
  my $qual   = readline($self->{fh});

  # Check 4 lines were found (FASTQ)
  return undef unless (defined $qual);
  # Fast format control: header and separator
  if ( (substr($header, 0, 1) eq '@') and (substr($check, 0, 1) eq '+') ) {
    chomp($header);
    chomp($seq);
    chomp($qual);
    # Also control sequence integrity
    if ($seq=~/^[ACGTNacgtn]+$/ and length($seq) == length($qual) ) {
      my ($name, $comments) = split /\s+/, substr($header, 1);
      $seq_object->{name} = $name;
      $seq_object->{comments} = $comments;
      $seq_object->{seq} = $seq;
      $seq_object->{qual} = $qual;
      $self->{counter}++;

    } else {
      # Return error (corrupted FASTQ)
      $self->{message} = "Unknown format: expecting FASTQ (corrupted?)";
      $self->{status} = 0;

    }
  } else {
    # Return error (not a FASTQ)
    $self->{message} = "Unknown format: expecting FASTQ (wrong header)";

    if (substr($seq, 0,1 ) eq '>' ) {
      # HINT: is FASTA?
      $self->{message} .= " (might be FASTA instead)";
    }
    $self->{status} = 0;
  }

  return $seq_object;
}

=head2 getFileFormat(filename)

This subroutine returns 'fasta', 'fastq' or <undef> for a given filepath (this is not a method of the instantiated object)

=cut
sub getFileFormat {
  my $self   = shift;
  my ($filename) = shift;
  return 0 if (not defined $filename);
  return $filename if (not -e "$filename");
  open my $f, '<:encoding(UTF-8)', "$filename" || confess "Unable to read $filename\n$!\n";
  my $first = readline($f);
  if (substr($first, 0,1) eq '>') {
    #should be FASTA
    return 'fasta';
  } elsif (substr($first, 0, 1) eq '@') {
    #should be fastq
    readline($f);
    my $sep = readline($f);
    if ( substr($sep, 0, 1) eq '+' ) {
      #second check for fastq
      return 'fastq';
    }
  } else {
    #unknown format
    return undef;
  }
}


=head1 ACKNOWLEDGEMENTS

=over 4

=item B<Heng Li's readfq()>

This mnodule is a wrapper around the I<readfq()> subroutine originally written by Heng Li, that I adapted
to retain I<sequence comments>.

See: L<readfq repository|https://github.com/telatin/readfq>

=back

=head1 CONTRIBUTORS

=over 4

=item B<Fabrizio Levorin>

has substantially contributed to the development of this module, and is a collaborator in the GitHub repository

=back

=cut
1;
