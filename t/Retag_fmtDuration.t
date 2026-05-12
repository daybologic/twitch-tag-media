#!/usr/bin/perl
# Twitch media tagger.
# Copyright (c) 2023-2026, Rev. Duncan Ross Palmer (2E0EOL)
# All rights reserved.

package Retag_fmtDuration_Tests;
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
	plan tests => 4;

	is(Daybo::Twitch::Retag::__fmtDuration(-1), '0.0s', 'negative duration clamps to zero');
	is(Daybo::Twitch::Retag::__fmtDuration(1.25), '1.2s', 'formats seconds');
	is(Daybo::Twitch::Retag::__fmtDuration(61.25), '1m 1.2s', 'formats minutes and seconds');
	is(Daybo::Twitch::Retag::__fmtDuration(3661.25), '1h 01m 1.2s', 'formats hours minutes and seconds');

	return EXIT_SUCCESS;
}

package main; ## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;
exit(Retag_fmtDuration_Tests->new->run);
