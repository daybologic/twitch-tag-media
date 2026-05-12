#!/usr/bin/perl
# Twitch media tagger.
# Copyright (c) 2023-2026, Rev. Duncan Ross Palmer (2E0EOL)
# All rights reserved.

package Retag_marker_Tests;
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use Daybo::Twitch::Retag;
use English qw(-no_match_vars);
use Log::Log4perl::MDC;
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

sub testSuccess {
	my ($self) = @_;
	plan tests => 3;

	my $stamp = '01:02:03.004';
	$self->mock('Daybo::Twitch::Retag', '__stamp', sub { return $stamp });

	is($self->sut->__marker(12.345), '', 'returns empty string');
	is(Log::Log4perl::MDC->get('stamp'), $stamp, 'updates stamp MDC');
	is(Log::Log4perl::MDC->get('pct'), ' 12.35%', 'updates percentage MDC');

	return EXIT_SUCCESS;
}

package main; ## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;
exit(Retag_marker_Tests->new->run);
