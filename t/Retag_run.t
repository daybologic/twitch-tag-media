#!/usr/bin/perl
# Twitch media tagger.
# Copyright (c) 2023-2026, Rev. Duncan Ross Palmer (2E0EOL)
# All rights reserved.

package Retag_run_Tests;
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use Daybo::Twitch::Retag;
use English qw(-no_match_vars);
use File::Temp qw(tempdir);
use POSIX qw(EXIT_SUCCESS);
use Test::Deep qw(cmp_deeply shallow);
use Test::More 0.96;

sub tearDown {
	my ($self) = @_;
	$self->clearMocks();
	return EXIT_SUCCESS;
}

sub _writeFile {
	my ($path, $content) = @_;
	open(my $fh, '>', $path) or die("Cannot create '$path': $ERRNO");
	print {$fh} $content;
	close($fh) or die("Cannot close '$path': $ERRNO");
	return;
}

sub testNoFiles {
	my ($self) = @_;
	plan tests => 1;

	my $sut = Daybo::Twitch::Retag->new();
	$self->mock('Daybo::Twitch::Retag', '__log', sub { return });
	$self->mock('Daybo::Twitch::Retag', '__marker', sub { return '' });

	is($sut->run('/tmp/' . $self->uniqueStr()), EXIT_SUCCESS, 'returns success when there is nothing to do');

	return EXIT_SUCCESS;
}

sub testSuccess {
	my ($self) = @_;
	plan tests => 2;

	my $dir = tempdir(CLEANUP => 1);
	my $file = "$dir/taucher66-2023-07-12.mp3";
	_writeFile($file, 'media');

	my $sut = Daybo::Twitch::Retag->new();
	$self->mock('Daybo::Twitch::TagWrap', 'isExtSupported', sub { return 1 });
	$self->mock('Daybo::Twitch::Retag', '__tag', sub { return });
	$self->mock('Daybo::Twitch::Retag', '__log', sub { return });
	$self->mock('Daybo::Twitch::Retag', '__marker', sub { return '' });
	$self->mock('Daybo::Twitch::Retag', 'time', sub { return 100 });

	is($sut->run($file), EXIT_SUCCESS, 'returns success after dispatching parseable file');
	my $calls = $self->mockCallsWithObject('Daybo::Twitch::Retag', '__tag');
	cmp_deeply($calls, [[
		shallow($sut),
		$file,
		100,
		5,
		'mp3',
		'Taucher',
		'Taucher on Twitch',
		'Taucher 2023-07-12 00:00:00',
		'2023',
	]], 'dispatches file with parsed tag fields') or diag(explain($calls));

	return EXIT_SUCCESS;
}

package main; ## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;
exit(Retag_run_Tests->new->run);
