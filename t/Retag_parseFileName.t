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

package Retag_parseFileName_Tests;
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

sub testSuccessDatePrefixed {
	my ($self) = @_;
	plan tests => 4;

	# Format: YYYY-MM-DD-HH-MM-SS-ArtistHandle.ext
	my $result = Daybo::Twitch::Retag::__parseFileName('2022-05-30-15-20-01-TestArtist.mp3');

	is($result->[0], 'Test Artist',                              'artist');
	is($result->[1], 'Test Artist on Twitch',                   'album');
	is($result->[2], 'Test Artist 2022-05-30 15:20:01',         'track');
	is($result->[3], '2022',                                     'year');

	return EXIT_SUCCESS;
}

sub testSuccessDateSuffixed {
	my ($self) = @_;
	plan tests => 4;

	# Format: ArtistHandle-YYYY-MM-DD.ext
	my $result = Daybo::Twitch::Retag::__parseFileName('TestArtist-2021-10-18.mp3');

	is($result->[0], 'Test Artist',                              'artist');
	is($result->[1], 'Test Artist on Twitch',                   'album');
	is($result->[2], 'Test Artist 2021-10-18 00:00:00',         'track');
	is($result->[3], '2021',                                     'year');

	return EXIT_SUCCESS;
}

sub testSuccessUnderscoreTypeDateSuffixed {
	my ($self) = @_;
	plan tests => 4;

	# Format: ArtistHandle_type_YYYY-MM-DD.ext
	my $result = Daybo::Twitch::Retag::__parseFileName('tkkttony_live_2026-07-03.mp4');

	is($result->[0], 'tkkttony',                              'artist');
	is($result->[1], 'tkkttony on Twitch',                   'album');
	is($result->[2], 'tkkttony 2026-07-03 00:00:00',         'track');
	is($result->[3], '2026',                                 'year');

	return EXIT_SUCCESS;
}

sub testSuccessStreamlinkRecorder {
	my ($self) = @_;
	plan tests => 4;

	# Format: ArtistHandle-YYYYMMDD-HHMMSS.mkv (streamlink-recorder)
	my $result = Daybo::Twitch::Retag::__parseFileName('TestArtist-20210613-184300.mkv');

	is($result->[0], 'Test Artist',                              'artist');
	is($result->[1], 'Test Artist on Twitch',                   'album');
	is($result->[2], 'Test Artist 2021-06-13 18:43:00',         'track');
	is($result->[3], '2021',                                     'year');

	return EXIT_SUCCESS;
}

sub testSuccessYtdlpWithStreamId {
	my ($self) = @_;
	plan tests => 4;

	# Format: ArtistHandle (type) YYYY-MM-DD HH_MM-StreamID.ext
	my $result = Daybo::Twitch::Retag::__parseFileName('TestArtist (live) 2021-10-18 11_05-40110166187.mp3');

	is($result->[0], 'Test Artist',                                           'artist');
	is($result->[1], 'Test Artist on Twitch',                                'album');
	is($result->[2], 'Test Artist 2021-10-18 11:05:00 40110166187',          'track');
	is($result->[3], '2021',                                                  'year');

	return EXIT_SUCCESS;
}

sub testSuccessYtdlpWithoutStreamId {
	my ($self) = @_;
	plan tests => 4;

	# Format: ArtistHandle (type) YYYY-MM-DD HH_MM.ext (no stream ID)
	my $result = Daybo::Twitch::Retag::__parseFileName('TestArtist (live) 2021-10-18 11_05.mp3');

	is($result->[0], 'Test Artist',                              'artist');
	is($result->[1], 'Test Artist on Twitch',                   'album');
	is($result->[2], 'Test Artist 2021-10-18 11:05:00',         'track');
	is($result->[3], '2021',                                     'year');

	return EXIT_SUCCESS;
}

sub testFailure {
	my ($self) = @_;
	plan tests => 1;

	my $result = Daybo::Twitch::Retag::__parseFileName('not-a-valid-filename.mp3');

	ok(!defined($result), 'returns undef for unrecognised filename');

	return EXIT_SUCCESS;
}

package main; ## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;
exit(Retag_parseFileName_Tests->new->run);
