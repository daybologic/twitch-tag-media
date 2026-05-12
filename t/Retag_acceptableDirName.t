#!/usr/bin/perl
# Twitch media tagger.
# Copyright (c) 2023-2026, Rev. Duncan Ross Palmer (2E0EOL)
# All rights reserved.

package Retag_acceptableDirName_Tests;
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use Daybo::Twitch::Retag;
use English qw(-no_match_vars);
use POSIX qw(EXIT_SUCCESS);
use Test::More 0.96;

sub testFailure {
	my ($self) = @_;
	plan tests => 1;

	ok(!Daybo::Twitch::Retag::__acceptableDirName('@eaDir'), 'rejects Synology metadata directory');

	return EXIT_SUCCESS;
}

sub testSuccess {
	my ($self) = @_;
	plan tests => 1;

	ok(Daybo::Twitch::Retag::__acceptableDirName($self->uniqueStr()), 'accepts ordinary directory name');

	return EXIT_SUCCESS;
}

package main; ## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;
exit(Retag_acceptableDirName_Tests->new->run);
