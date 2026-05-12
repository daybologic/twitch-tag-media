#!/usr/bin/perl
# Twitch media tagger.
# Copyright (c) 2023-2026, Rev. Duncan Ross Palmer (2E0EOL)
# All rights reserved.

package Retag_parseFileName_Tests;
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use Daybo::Twitch::Retag;
use English qw(-no_match_vars);
use POSIX qw(EXIT_SUCCESS);
use Test::Deep qw(cmp_deeply);
use Test::More 0.96;

sub testFailure {
	my ($self) = @_;
	plan tests => 1;

	ok(!defined(Daybo::Twitch::Retag::__parseFileName($self->uniqueStr() . '.mp3')), 'returns undef for unparseable filename');

	return EXIT_SUCCESS;
}

sub testSuccess {
	my ($self) = @_;
	plan tests => 4;

	cmp_deeply(
		Daybo::Twitch::Retag::__parseFileName('1stdegreeproductions (live) 2021-10-18 11_05-40110166187.mp3'),
		['1stdegreeproductions', '1stdegreeproductions on Twitch', '1stdegreeproductions 2021-10-18 11:05:00 40110166187', '2021'],
		'parses yt-dlp live filename with stream id',
	);

	cmp_deeply(
		Daybo::Twitch::Retag::__parseFileName('2022-05-30-15-20-01-vlastimilvibes.mp3'),
		['Vlastimil', 'Vlastimil on Twitch', 'Vlastimil 2022-05-30 15:20:01', '2022'],
		'parses date-first filename',
	);

	cmp_deeply(
		Daybo::Twitch::Retag::__parseFileName('taucher66-2023-07-12.mp4'),
		['Taucher', 'Taucher on Twitch', 'Taucher 2023-07-12 00:00:00', '2023'],
		'parses artist-date filename',
	);

	is(
		Daybo::Twitch::Retag::__parseFileName('taucher66-2023-07-12.mp4'),
		Daybo::Twitch::Retag::__parseFileName('taucher66-2023-07-12.mp4'),
		'returns cached parse result for repeated filename',
	);

	return EXIT_SUCCESS;
}

package main; ## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;
exit(Retag_parseFileName_Tests->new->run);
