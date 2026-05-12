#!/usr/bin/perl
# Twitch media tagger.
# Copyright (c) 2023-2026, Rev. Duncan Ross Palmer (2E0EOL)
# All rights reserved.

package Retag_fixWorldSuffix_Tests;
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use Daybo::Twitch::Retag;
use English qw(-no_match_vars);
use POSIX qw(EXIT_SUCCESS);
use Test::More 0.96;

sub testSuccess {
	my ($self) = @_;
	plan tests => 3;

	is(Daybo::Twitch::Retag::__fixWorldSuffix('Dreamworld'), 'Dream world', 'splits trailing world suffix');
	is(Daybo::Twitch::Retag::__fixWorldSuffix('Artist Uk'), 'Artist UK', 'normalises UK suffix');
	is(Daybo::Twitch::Retag::__fixWorldSuffix('World Music'), 'World Music', 'leaves non-suffix world alone');

	return EXIT_SUCCESS;
}

package main; ## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;
exit(Retag_fixWorldSuffix_Tests->new->run);
