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

package MKV_readTags_Tests;
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use Daybo::Twitch::TagWrap::Backend::MKV;
use English qw(-no_match_vars);
use POSIX qw(EXIT_SUCCESS);
use Test::Deep qw(cmp_deeply);
use Test::More 0.96;

sub setUp {
	my ($self) = @_;

	$self->sut(Daybo::Twitch::TagWrap::Backend::MKV->new());

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

	my ($mockPackage, $mockMethod) = ('Daybo::Twitch::TagWrap::Backend::MKV', '__readTagXml');
	$self->mock($mockPackage, $mockMethod, sub { return undef });

	my $result = $self->sut->readTags($self->uniqueStr());
	is($result, undef, 'undef returned when __readTagXml fails');

	return EXIT_SUCCESS;
}

sub testSuccess {
	my ($self) = @_;
	plan tests => 1;

	my $artist = $self->uniqueStr();
	my $xml    = "<Tags><Tag><Targets/>"
		. "<Simple><Name>ARTIST</Name><String>${artist}</String></Simple>"
		. "</Tag></Tags>";

	my ($mockPackage, $mockMethod) = ('Daybo::Twitch::TagWrap::Backend::MKV', '__readTagXml');
	$self->mock($mockPackage, $mockMethod, sub { return $xml });

	my $result = $self->sut->readTags($self->uniqueStr());
	cmp_deeply($result, { artist => $artist }, 'parse result flows through from __readTagXml')
		or diag(explain($result));

	return EXIT_SUCCESS;
}

package main; ## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;
exit(MKV_readTags_Tests->new->run);
