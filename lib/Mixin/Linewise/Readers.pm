use strict;
use warnings;
package Mixin::Linewise::Readers;
# ABSTRACT: get linewise readers for strings and filenames

use 5.008001; # PerlIO
use Carp ();
use IO::File;
use PerlIO::utf8_strict;

use Sub::Exporter -setup => {
  exports => { map {; "read_$_" => \"_mk_read_$_" } qw(file string) },
  groups  => {
    default => [ qw(read_file read_string) ],
    readers => [ qw(read_file read_string) ],
  },
};

use version;
our $VERSION = version->parse('0.110_01');

=head1 SYNOPSIS

  package Your::Pkg;
  use Mixin::Linewise::Readers -readers;

  sub read_handle {
    my ($self, $handle) = @_;

    LINE: while (my $line = $handle->getline) {
      next LINE if $line =~ /^#/;

      print "non-comment: $line";
    }
  }

Then:

  use Your::Pkg;

  Your::Pkg->read_file($filename);

  Your::Pkg->read_string($string);

  Your::Pkg->read_handle($fh);

=head1 EXPORTS

C<read_file> and C<read_string> are exported by default.  Either can be
requested individually, or renamed.  They are generated by
L<Sub::Exporter|Sub::Exporter>, so consult its documentation for more
information.

Both can be generated with the option "method" which requests that a method
other than "read_handle" is called with the created IO::Handle.

If given a "binmode" option, any C<read_file> type functions will use
that as an IO layer, otherwise, the default is C<utf8_strict>.

  use Mixin::Linewise::Readers -readers => { binmode => "raw" };
  use Mixin::Linewise::Readers -readers => { binmode => "encoding(iso-8859-1)" };

=head2 read_file

  Your::Pkg->read_file($filename);
  Your::Pkg->read_file(\%options, $filename);

If generated, the C<read_file> export attempts to open the named file for
reading, and then calls C<read_handle> on the opened handle.

An optional hash reference may be passed before C<$filename> with options.
The only valid option currently is C<binmode>, which overrides any
default set from C<use> or the built-in C<utf8_strict>.

Any arguments after C<$filename> are passed along after to C<read_handle>.

=cut

sub _mk_read_file {
  my ($self, $name, $arg) = @_;

  my $method = defined $arg->{method} ? $arg->{method} : 'read_handle';
  my $dflt_enc = defined $arg->{binmode} ? $arg->{binmode} : 'utf8_strict';

  sub {
    my ($invocant, $options, $filename);
    if ( ref $_[1] eq 'HASH' ) {
      # got options before filename
      ($invocant, $options, $filename) = splice @_, 0, 3;
    }
    else {
      ($invocant, $filename) = splice @_, 0, 2;
    }

    my $binmode = defined $options->{binmode} ? $options->{binmode} : $dflt_enc;
    $binmode =~ s/^://; # we add it later

    # Check the file
    Carp::croak "no filename specified"           unless $filename;
    Carp::croak "file '$filename' does not exist" unless -e $filename;
    Carp::croak "'$filename' is not readable"     unless -r _ && ! -d _;

    my $handle = IO::File->new($filename, "<:$binmode")
      or Carp::croak "couldn't read file '$filename': $!";

    $invocant->$method($handle, @_);
  }
}

=head2 read_string

  Your::Pkg->read_string($string);
  Your::Pkg->read_string(\%option, $string);

If generated, the C<read_string> creates a handle on the given string, and
then calls C<read_handle> on the opened handle.  Because handles on strings
must be octet-oriented, the string B<must contain octets>.  It will be opened
in the default binmode established by importing.  (See L</EXPORTS>, above.)

Any arguments after C<$string> are passed along after to C<read_handle>.

Like C<read_file>, this method can take a leading hashref with one valid
argument: C<binmode>.

=cut

sub _mk_read_string {
  my ($self, $name, $arg) = @_;

  my $method = defined $arg->{method} ? $arg->{method} : 'read_handle';
  my $dflt_enc = defined $arg->{binmode} ? $arg->{binmode} : 'utf8_strict';

  sub {
    my ($opt) = @_ > 2 && ref $_[1] ? splice(@_, 1, 1) : undef;
    my ($invocant, $string) = splice @_, 0, 2;

    my $binmode = ($opt && $opt->{binmode}) ? $opt->{binmode} : $dflt_enc;
    $binmode =~ s/^://; # we add it later

    Carp::croak "no string provided" unless defined $string;

    open my $handle, "<:$binmode", \$string
      or die "error opening string for reading: $!";

    $invocant->$method($handle, @_);
  }
}

1;
