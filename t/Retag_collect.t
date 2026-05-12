#!/usr/bin/perl
# Twitch media tagger.
# Copyright (c) 2023-2026, Rev. Duncan Ross Palmer (2E0EOL)
# All rights reserved.

package Retag_collect_Tests;
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use Daybo::Twitch::Retag;
use English qw(-no_match_vars);
use File::Path qw(make_path);
use File::Temp qw(tempdir);
use POSIX qw(EXIT_SUCCESS);
use Test::Deep qw(bag cmp_deeply);
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

sub testFailure {
	my ($self) = @_;
	plan tests => 1;

	my $sut = Daybo::Twitch::Retag->new();
	$self->mock('Daybo::Twitch::Retag', '__log', sub { return });

	is($sut->__collect('/tmp/' . $self->uniqueStr()), -1, 'returns -1 when directory cannot be opened');

	return EXIT_SUCCESS;
}

sub testSuccess {
	my ($self) = @_;
	plan tests => 2;

	my $dir = tempdir(CLEANUP => 1);
	my $subdir = "$dir/sub";
	my $eaDir = "$dir/\@eaDir";
	make_path($subdir, $eaDir);

	my $good = 'taucher66-2023-07-12.mp3';
	my $nested = 'vlastimilvibes-2022-01-02.mp3';
	_writeFile("$dir/$good", 'good');
	_writeFile("$subdir/$nested", 'nested');
	_writeFile("$dir/unparseable.mp3", 'bad');
	_writeFile("$dir/taucher66-2023-07-12.temp.mp3", 'temp');
	_writeFile("$dir/taucher66-2023-07-12.txt", 'unsupported');
	_writeFile("$eaDir/taucher66-2023-07-12.mp3", 'ignored');

	my $sut = Daybo::Twitch::Retag->new(recursive => 1);
	$sut->_stats({ start_time => 0 });
	$self->mock('Daybo::Twitch::TagWrap', 'isExtSupported', sub {
		my (undef, $ext) = @_;
		return ($ext eq 'mp3');
	});
	$self->mock('Daybo::Twitch::Retag', '__log', sub { return });
	$self->mock('Daybo::Twitch::Retag', '__marker', sub { return '' });

	my $files = $sut->__collect($dir);

	cmp_deeply($files, bag(
		["$dir/$good", $good, 4, 'mp3'],
		["$subdir/$nested", $nested, 6, 'mp3'],
	), 'collects supported parseable files recursively and skips @eaDir');
	cmp_deeply($sut->_stats, {
		start_time => 0,
		seen_files => 5,
		seen_bytes => 4 + 6 + 3 + 4 + 11,
		unqualified_files => 3,
		unqualified_bytes => 3 + 4 + 11,
	}, 'updates seen and unqualified stats');

	return EXIT_SUCCESS;
}

package main; ## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;
exit(Retag_collect_Tests->new->run);
