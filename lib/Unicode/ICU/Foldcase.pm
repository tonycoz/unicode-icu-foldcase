package Unicode::ICU::Foldcase;
use strict;
use Exporter qw(import);

BEGIN {
  our $VERSION = '0.001';
  use XSLoader;
  XSLoader::load('Unicode::ICU::Foldcase' => $VERSION);
}

{
  our %EXPORT_TAGS =
    (
     case => [ "fc", "lc", "uc", "tc" ],
     locale => [ "lc_loc", "uc_loc", "tc_loc" ],
    );

  our @EXPORT_OK = map @$_, values %EXPORT_TAGS;
}

1;

__END__

=head1 NAME

Unicode::ICU::Foldcase - wrapper around ICU case folding services

=head1 SYNOPSIS

  use Unicode::ICU::Foldcase ':case';

  my $upper = uc $text;
  my $lower = lc $text;
  my $fold = fc $text;
  my $title = tc $text;

  use Unicode::ICU::Foldcase ':locale';

  my $upper = uc_loc $text, $locale;
  my $lower = lc_loc $text, $locale;
  my $title = tc_loc $text, $locale;

=head1 DESCRIPTION

Unicode::ICU::Foldcase is a thin (and currently incomplete) wrapper
around ICU's case folding functions.

=head1 FUNCTIONS

=over

=item uc $in

=item lc $in

=item tc $in

=item fc $in

Return the upper-case, lower-case, title-cased or fold-cased
transformation of the input.

=item uc_loc $in, $locale

=item lc_loc $in, $locale

=item tc_loc $in, $locale

Return the upper-case, lower-case or title-cased transformation of the
input in the given locale.

=back

=head1 LICENSE

Unicode::ICU::Foldcase is licensed under the same terms as Perl itself.

=head1 SEE ALSO

http://site.icu-project.org/

http://userguide.icu-project.org/transforms/casemappings

http://icu-project.org/apiref/icu4c/ustring_8h.html

L<perlfunc/uc>, L<perlfunc/lc>, L<perlfunc/fc>

=head1 AUTHOR

Tony Cook <tonyc@cpan.org>

=cut


