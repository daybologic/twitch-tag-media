#!/usr/bin/perl
# Twitch media tagger.
# Copyright (c) 2023-2026, Rev. Duncan Ross Palmer (2E0EOL)
# All rights reserved.

package Retag_initStats_Tests;
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

sub setUp {
	my ($self) = @_;

	$self->sut(Daybo::Twitch::Retag->new());

	return EXIT_SUCCESS;
}

sub tearDown {
	my ($self) = @_;
	$self->clearMocks();
	return EXIT_SUCCESS;
}

sub testSuccess {
	my ($self) = @_;
	plan tests => 1;

	my $start = $self->unique();
	$self->mock('Daybo::Twitch::Retag', 'time', sub { return $start });

	$self->sut->__initStats();

	cmp_deeply($self->sut->_stats, {
		total_files       => 0,
		modified_files    => 0,
		skipped_files     => 0,
		total_bytes       => 0,
		modified_bytes    => 0,
		skipped_bytes     => 0,
		tags_altered      => 0,
		unqualified_bytes => 0,
		unqualified_files => 0,
		seen_files        => 0,
		seen_bytes        => 0,
		start_time        => $start,
		end_time          => 0,
	}, 'initialises all stats counters');

	return EXIT_SUCCESS;
}

package main; ## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;
exit(Retag_initStats_Tests->new->run);
