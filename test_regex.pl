use strict;
use warnings;

my @tests = (
    '/usr/bin/perl:VAR=VAL',
    'C:\perl\bin\perl:VAR=VAL',
    'perl5.30.0:VAR=VAL',
    ':GLOBAL_VAR=VAL',
);

for my $t (@tests) {
    if ($t =~ m{^(.*):([^:=]+)=(.*)$}) {
        printf "Path: [%s], Var: [%s], Val: [%s]\n", $1, $2, $3;
    } else {
        print "Failed to match: $t\n";
    }
}
