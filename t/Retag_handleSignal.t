#!/usr/bin/perl
# Twitch media tagger.
# Copyright (c) 2023-2026, Rev. Duncan Ross Palmer (2E0EOL)
# All rights reserved.

package Retag_handleSignal_Tests;
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use Daybo::Twitch::Retag;
use English qw(-no_match_vars);
use Log::Log4perl qw(:levels);
use POSIX qw(EXIT_SUCCESS);
use Test::Deep qw(cmp_deeply shallow);
use Test::More 0.96;

sub setUp {
	my ($self) = @_;

	$self->sut(Daybo::Twitch::Retag->new(json => 1));
	$self->mock('Daybo::Twitch::Retag', '__log', sub { return });

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

	$self->sut->__handleSignal('INT');

	my $calls = $self->mockCallsWithObject('Daybo::Twitch::Retag', '__log');
	cmp_deeply($calls, [[
		shallow($self->sut),
		$WARN,
		{
			process => { type => 'signal' },
			signal => 'INT',
			action => 'draining',
			children => 0,
		},
	]], 'logs first signal as draining');

	return EXIT_SUCCESS;
}

package main; ## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;
exit(Retag_handleSignal_Tests->new->run);
