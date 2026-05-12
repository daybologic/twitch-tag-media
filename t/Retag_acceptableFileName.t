#!/usr/bin/perl
# Twitch media tagger.
# Copyright (c) 2023-2026, Rev. Duncan Ross Palmer (2E0EOL)
# All rights reserved.

package Retag_acceptableFileName_Tests;
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

	ok(!Daybo::Twitch::Retag::__acceptableFileName('artist.temp.mp4'), 'rejects yt-dlp temp filename');

	return EXIT_SUCCESS;
}

sub testSuccess {
	my ($self) = @_;
	plan tests => 2;

	ok(Daybo::Twitch::Retag::__acceptableFileName('artist.mp4'), 'accepts ordinary filename');
	ok(Daybo::Twitch::Retag::__acceptableFileName('artist.temp'), 'accepts temp as final extension');

	return EXIT_SUCCESS;
}

package main; ## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;
exit(Retag_acceptableFileName_Tests->new->run);
