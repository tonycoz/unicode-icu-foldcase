use 5.008008;
use strict;
use ExtUtils::MakeMaker;
use Text::ParseWords qw(shellwords);
use ExtUtils::Constant qw(WriteConstants);

my $cflags = `icu-config --cppflags`
  or die "OS unsupported: No icu-config --cppflags found\n";
my $libs = `icu-config --ldflags`
  or die "OS unsupported: No icu-config libraries\n";
chomp $cflags;
chomp $libs;

# cppflags includes both defines and -I options, separate them out
my @define;
my @inc;
for my $flag (shellwords $cflags) {
  if ($flag =~ /^-I/) {
    push @inc, $flag;
  }
  else {
    push @define, $flag;
  }
}

@define = requote(@define);
@inc = requote(@inc);

my %opts = 
  (
   NAME => 'Unicode::ICU::Foldcase',
   VERSION_FROM => 'lib/Unicode/ICU/Foldcase.pm',
   OBJECT => 'Foldcase.o',
   DEFINE => "@define",
   INC => "@inc",
   LIBS => $libs,
   PREREQ_PM =>
   {
    'Test::More' => '0.47',
    XSLoader => 0,
   },
  );
my $eu_mmv = eval $ExtUtils::MakeMaker::VERSION;
if ($eu_mmv > 6.06) {
  $opts{AUTHOR} = 'Tony Cook <tonyc@cpan.org>';
  $opts{ABSTRACT} = 'Wrapper around ICU case folding services';
}
if ($eu_mmv > 6.30) {
  $opts{LICENSE} = 'perl';
}

WriteMakefile(%opts);

sub requote {
  return map { / / ? qq("$_") : $_ } @_;
}
