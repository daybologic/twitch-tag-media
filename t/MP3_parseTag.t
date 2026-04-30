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

package MP3_parseTag_Tests;
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use Daybo::Twitch::TagWrap::Backend::MP3;
use English qw(-no_match_vars);
use POSIX qw(EXIT_SUCCESS);
use Test::More 0.96;

sub setUp {
	my ($self) = @_;

	$self->sut(Daybo::Twitch::TagWrap::Backend::MP3->new());

	return EXIT_SUCCESS;
}

sub testAlbum {
	my ($self) = @_;
	plan tests => 1;

	my %tags;
	my $value = $self->uniqueStr();
	Daybo::Twitch::TagWrap::Backend::MP3::__parseTag(\%tags, "TALB (TALB): $value");
	is($tags{album}, $value, 'album extracted from TALB line');

	return EXIT_SUCCESS;
}

sub testArtist {
	my ($self) = @_;
	plan tests => 1;

	my %tags;
	my $value = $self->uniqueStr();
	Daybo::Twitch::TagWrap::Backend::MP3::__parseTag(\%tags, "TPE1 (TPE1): $value");
	is($tags{artist}, $value, 'artist extracted from TPE1 line');

	return EXIT_SUCCESS;
}

sub testComment {
	my ($self) = @_;
	plan tests => 2;

	my %tags;
	my $value = $self->uniqueStr();
	Daybo::Twitch::TagWrap::Backend::MP3::__parseTag(\%tags, "COMM (COMM): (eng)[eng]: $value");
	is($tags{comment}, $value, 'comment extracted when lang/desc prefix present');

	%tags = ();
	$value = $self->uniqueStr();
	Daybo::Twitch::TagWrap::Backend::MP3::__parseTag(\%tags, "COMM (COMM): $value");
	is($tags{comment}, $value, 'comment extracted when no lang/desc prefix');

	return EXIT_SUCCESS;
}

sub testTrack {
	my ($self) = @_;
	plan tests => 1;

	my %tags;
	my $value = $self->uniqueStr();
	Daybo::Twitch::TagWrap::Backend::MP3::__parseTag(\%tags, "TIT2 (TIT2): $value");
	is($tags{track}, $value, 'track extracted from TIT2 line');

	return EXIT_SUCCESS;
}

sub testUnrecognised {
	my ($self) = @_;
	plan tests => 1;

	my %tags;
	Daybo::Twitch::TagWrap::Backend::MP3::__parseTag(\%tags, 'WXXX (WXXX): ' . $self->uniqueStr());
	is(scalar(keys(%tags)), 0, 'unrecognised tag frame leaves tags empty');

	return EXIT_SUCCESS;
}

sub testYear {
	my ($self) = @_;
	plan tests => 1;

	my %tags;
	my $value = $self->unique();
	Daybo::Twitch::TagWrap::Backend::MP3::__parseTag(\%tags, "TYER (TYER): $value");
	is($tags{year}, $value, 'year extracted from TYER line');

	return EXIT_SUCCESS;
}

package main; ## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;
exit(MP3_parseTag_Tests->new->run);
