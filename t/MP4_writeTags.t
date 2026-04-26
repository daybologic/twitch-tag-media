#!/usr/bin/perl
# Twitch media tagger.
# Copyright (c) 2023-2026, Rev. Duncan Ross Palmer (2E0EOL)
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#     * Redistributions of source code must retain the above copyright notice,
#       this list of conditions and the following disclaimer.
#
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#
#     * Neither the name of the the maintainer, nor the names of its contributors
#       may be used to endorse or promote products derived from this software
#       without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

package MP4_writeTags_Tests;
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use Daybo::Twitch::TagWrap::Backend::MP4;
use English qw(-no_match_vars);
use POSIX qw(EXIT_SUCCESS);
use Test::Deep qw(cmp_deeply shallow);
use Test::Exception;
use Test::More 0.96;

sub setUp {
	my ($self) = @_;

	$self->sut(Daybo::Twitch::TagWrap::Backend::MP4->new());

	return EXIT_SUCCESS;
}

sub tearDown {
	my ($self) = @_;
	$self->clearMocks();
	return EXIT_SUCCESS;
}

sub testFailure {
	my ($self) = @_;
	plan tests => 1;

	my $file    = '/tmp/' . $self->uniqueStr() . '.mp4';
	my $artist  = $self->uniqueStr();
	my $album   = $self->uniqueStr();
	my $track   = $self->uniqueStr();
	my $year    = $self->unique();
	my $comment = $self->uniqueStr();
	my $temp    = $self->uniqueStr();

	open(my $fake_fh, '<', \my $dummy) or die("could not open string ref: $ERRNO");

	my $mp4Package = 'Daybo::Twitch::TagWrap::Backend::MP4';
	$self->mock($mp4Package, 'tempfile', sub { return ($fake_fh, $temp) });
	$self->mock('Daybo::Twitch::TagWrap::Backend', '_system', sub { return 1 });

	throws_ok(
		sub { $self->sut->writeTags($file, $artist, $album, $track, $year, $comment) },
		qr/ffmpeg failed for '\Q$file\E'/,
		'dies when ffmpeg exits non-zero',
	);

	return EXIT_SUCCESS;
}

sub testMoveFailure {
	my ($self) = @_;
	plan tests => 1;

	my $file    = '/tmp/' . $self->uniqueStr() . '.mp4';
	my $artist  = $self->uniqueStr();
	my $album   = $self->uniqueStr();
	my $track   = $self->uniqueStr();
	my $year    = $self->unique();
	my $comment = $self->uniqueStr();
	my $temp    = $self->uniqueStr();

	open(my $fake_fh, '<', \my $dummy) or die("could not open string ref: $ERRNO");

	my $mp4Package = 'Daybo::Twitch::TagWrap::Backend::MP4';
	$self->mock($mp4Package, 'tempfile', sub { return ($fake_fh, $temp) });
	$self->mock('Daybo::Twitch::TagWrap::Backend', '_system', sub { return 0 });
	$self->mock($mp4Package, 'move', sub { return 0 });

	throws_ok(
		sub { $self->sut->writeTags($file, $artist, $album, $track, $year, $comment) },
		qr/Failed to move '\Q$temp\E' to '\Q$file\E'/,
		'dies when move fails',
	);

	return EXIT_SUCCESS;
}

sub testSuccess {
	my ($self) = @_;
	plan tests => 3;

	my $file    = '/tmp/' . $self->uniqueStr() . '.mp4';
	my $artist  = $self->uniqueStr();
	my $album   = $self->uniqueStr();
	my $track   = $self->uniqueStr();
	my $year    = $self->unique();
	my $comment = $self->uniqueStr();
	my $temp    = $self->uniqueStr();

	open(my $fake_fh, '<', \my $dummy) or die("could not open string ref: $ERRNO");

	my $mp4Package = 'Daybo::Twitch::TagWrap::Backend::MP4';
	$self->mock($mp4Package, 'tempfile', sub { return ($fake_fh, $temp) });
	$self->mock('Daybo::Twitch::TagWrap::Backend', '_system', sub { return 0 });
	$self->mock($mp4Package, 'move', sub { return 1 });

	lives_ok(
		sub { $self->sut->writeTags($file, $artist, $album, $track, $year, $comment) },
		'writeTags returns without dying',
	);

	my $systemCalls = $self->mockCallsWithObject('Daybo::Twitch::TagWrap::Backend', '_system');
	cmp_deeply($systemCalls, [[
		shallow($self->sut),
		'ffmpeg',
		'-nostdin',
		'-y',
		'-i',        $file,
		'-c',        'copy',
		'-movflags', '+faststart',
		'-f',        'mp4',
		'-metadata', "artist=$artist",
		'-metadata', "album=$album",
		'-metadata', "date=$year",
		'-metadata', "title=$track",
		'-metadata', "comment=$comment",
		$temp,
	]], 'ffmpeg called with correct args') or diag(explain($systemCalls));

	my $moveCalls = $self->mockCallsWithObject($mp4Package, 'move');
	cmp_deeply($moveCalls, [[$temp, $file]], 'temp file moved to destination')
		or diag(explain($moveCalls));

	return EXIT_SUCCESS;
}

package main; ## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;
exit(MP4_writeTags_Tests->new->run);
