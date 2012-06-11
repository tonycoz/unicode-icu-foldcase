#!perl -w
use strict;
use Test::More;

use Unicode::ICU::Foldcase qw(fc);

plan tests => 1;

is(fc("Abc"), "abc", "check simple foldcase");