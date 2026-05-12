#!/usr/bin/perl
# Twitch media tagger.
# Copyright (c) 2023-2026, Rev. Duncan Ross Palmer (2E0EOL)
# All rights reserved.

package Retag_makeJobs_Tests;
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use Daybo::Twitch::Retag;
use English qw(-no_match_vars);
use POSIX qw(EXIT_SUCCESS);
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

sub testSingleCore {
	my ($self) = @_;
	plan tests => 1;

	$self->mock('Sys::CPU', 'cpu_count', sub { return 1 });
	$self->mock('Daybo::Twitch::Retag', '__log', sub { return });
	$self->mock('Daybo::Twitch::Retag', '__marker', sub { return '' });

	is($self->sut->__makeJobs(), 1, 'uses one job on a single-core system');

	return EXIT_SUCCESS;
}

sub testSuccess {
	my ($self) = @_;
	plan tests => 1;

	$self->mock('Sys::CPU', 'cpu_count', sub { return 4 });
	$self->mock('Daybo::Twitch::Retag', '__log', sub { return });
	$self->mock('Daybo::Twitch::Retag', '__marker', sub { return '' });

	is($self->sut->__makeJobs(), 5, 'uses one more than detected core count');

	return EXIT_SUCCESS;
}

package main; ## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;
exit(Retag_makeJobs_Tests->new->run);
