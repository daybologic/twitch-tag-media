#!/usr/bin/perl
# Twitch media tagger.
# Copyright (c) 2023-2026, Rev. Duncan Ross Palmer (2E0EOL)
# All rights reserved.

package Retag_fixConjunctions_Tests;
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

	is(Daybo::Twitch::Retag::__fixConjunctions('Stoneface And Terminal'), 'Stoneface and Terminal', 'lowercases interior and');
	is(Daybo::Twitch::Retag::__fixConjunctions('On And Or'), 'On and Or', 'leaves first and last words alone');
	is(Daybo::Twitch::Retag::__fixConjunctions('A And'), 'A And', 'leaves two-word names alone');

	return EXIT_SUCCESS;
}

package main; ## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;
exit(Retag_fixConjunctions_Tests->new->run);
