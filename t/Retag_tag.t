#!/usr/bin/perl
# Twitch media tagger.
# Copyright (c) 2023-2026, Rev. Duncan Ross Palmer (2E0EOL)
# All rights reserved.

package Retag_tag_Tests;
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

	$self->sut(Daybo::Twitch::Retag->new(jobs => 8));
	$self->sut->_stats({
		total_files    => 0,
		total_bytes    => 0,
		modified_files => 0,
		modified_bytes => 0,
		skipped_files  => 0,
		skipped_bytes  => 0,
		tags_altered   => 0,
		start_time     => 0,
	});
	$self->sut->__originalProgramName($PROGRAM_NAME);
	$self->mock('Daybo::Twitch::Retag', '__tagPerProcess', sub { return (1, 2) });
	$self->mock('Daybo::Twitch::Retag', '__log', sub { return });
	$self->mock('Daybo::Twitch::Retag', '__marker', sub { return '' });

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

	$self->sut->__tag('/tmp/file.mp3', 100, 7, 'mp3', 'Artist', 'Album', 'Track', '2024');
	my $pid = waitpid(-1, 0);
	$self->sut->__reapChild($pid, 100);

	cmp_deeply($self->sut->_stats, {
		total_files    => 1,
		total_bytes    => 7,
		modified_files => 1,
		modified_bytes => 7,
		skipped_files  => 0,
		skipped_bytes  => 0,
		tags_altered   => 2,
		start_time     => 0,
	}, 'forks child and records child result for reaping');

	return EXIT_SUCCESS;
}

package main; ## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;
exit(Retag_tag_Tests->new->run);
