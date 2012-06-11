#!perl -w
use strict;
use Test::More;

use Unicode::ICU::Foldcase qw(tc tc_loc);

plan tests => 3;

is(tc_loc("ijabc", "nl"), "IJabc", "check NL locale title case");
is(tc_loc("ijabc", "en"), "Ijabc", "check EN locale title case");

is(tc("ijabc"), "Ijabc", "check non-locale title case");