#!perl -T
use 5.020;
use warnings;
use Test::More tests => 11;

BEGIN {
    if ($ENV{AUTHOR_TESTING}) {
        require Devel::Cover;
        import Devel::Cover -db => 'cover_db', -coverage => qw(branch condition statement subroutine), -silent => 1, '+ignore' => qr'^t/';
    }
}

use Plate;

my $warned;
$SIG{__WARN__} = sub {
    $warned = 1;
    goto &diag;
};

my $plate = new Plate;

is $plate->serve(\<<'PLATE'),
% if (@_) {
args=<% scalar @_ %>
% } else {
no args
% }
PLATE
"no args\n",
'Statement lines';

is $plate->serve(\<<'PLATE', 1..3),
%# This is a comment on line 1
% if (@_) {
args=<% scalar @_ %>
% } else { # This is a comment on line 4
no args
% }
% # This is a comment on line 7
PLATE
"args=3\n",
'Comment lines';

is $plate->serve(\"% if (1) {\nYES\n% }"), $plate->serve(\"% if (1) {\nYES\n% }\n"), 'Ignore final newline if last line is a statement';

my $fail = eval { $plate->serve(\<<'PLATE') };
% if (1) {
PLATE
is $fail, undef, 'Compilation failed';
like $@, qr/^Missing right curly or square bracket at .*^Plate compilation failed at /ms,
'Compilation failure message';

$fail = eval { $plate->serve(\<<'PLATE') };
%% if (1) {
PLATE
is $fail, undef, 'Precompilation failed';
like $@, qr/^Missing right curly or square bracket at .*^Plate precompilation failed at /ms,
'Precompilation failure message';

$fail = eval { $plate->serve(\<<'PLATE') };
%% my $precomp_var;
% $precomp_var = 1;
PLATE
is $fail, undef, 'Compilation failed';
like $@, qr'^Global symbol "\$precomp_var" requires explicit package name .*^Plate compilation failed at 'ms,
'Precompilation doesnt affect runtime';

$plate->set(init => q{
    Plate::_local_args(__PACKAGE__, shift) if @_;
}, once => q{
    no strict 'vars';
}, keep_undef => 1);

$plate->define(empty => '');
is $plate->serve(\<<'PLATE', { empty => '', '@empty' => [''] }),
%%# Empty
<%% '' %%>\
<% $empty %>\
<% @empty %>\
<&& empty &&>\
%%# Empty
PLATE
'',
'Empty template';

ok !$warned, 'No warnings';
