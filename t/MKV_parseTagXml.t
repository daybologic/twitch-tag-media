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

package MKV_parseTagXml_Tests;
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

sub testNoTags {
	my ($self) = @_;
	plan tests => 1;

	my $xml = "<Tags><Tag><Targets/></Tag></Tags>";
	my $result = Daybo::Twitch::TagWrap::Backend::MKV::__parseTagXml($xml);
	is($result, undef, 'undef returned when no recognised tags present');

	return EXIT_SUCCESS;
}

sub testSuccess {
	my ($self) = @_;
	plan tests => 1;

	my $artist  = $self->uniqueStr();
	my $album   = $self->uniqueStr();
	my $track   = $self->uniqueStr();
	my $year    = $self->unique();
	my $comment = $self->uniqueStr();

	my $xml = "<Tags><Tag><Targets/>\n"
		. "<Simple><Name>ARTIST</Name><String>${artist}</String></Simple>\n"
		. "<Simple><Name>ALBUM</Name><String>${album}</String></Simple>\n"
		. "<Simple><Name>TITLE</Name><String>${track}</String></Simple>\n"
		. "<Simple><Name>DATE_RELEASED</Name><String>${year}</String></Simple>\n"
		. "<Simple><Name>COMMENT</Name><String>${comment}</String></Simple>\n"
		. "</Tag></Tags>";

	my $result = Daybo::Twitch::TagWrap::Backend::MKV::__parseTagXml($xml);
	cmp_deeply($result, {
		artist  => $artist,
		album   => $album,
		track   => $track,
		year    => "$year",
		comment => $comment,
	}, 'all recognised fields extracted and returned') or diag(explain($result));

	return EXIT_SUCCESS;
}

sub testUnrecognisedName {
	my ($self) = @_;
	plan tests => 1;

	my $xml = "<Tags><Tag><Targets/>"
		. "<Simple><Name>UNKNOWN_FIELD</Name><String>" . $self->uniqueStr() . "</String></Simple>"
		. "</Tag></Tags>";
	my $result = Daybo::Twitch::TagWrap::Backend::MKV::__parseTagXml($xml);
	is($result, undef, 'undef returned when only unrecognised field names present');

	return EXIT_SUCCESS;
}

sub testXmlUnescape {
	my ($self) = @_;
	plan tests => 1;

	my $xml = "<Tags><Tag><Targets/>"
		. "<Simple><Name>ARTIST</Name><String>AC&amp;DC</String></Simple>"
		. "</Tag></Tags>";
	my $result = Daybo::Twitch::TagWrap::Backend::MKV::__parseTagXml($xml);
	cmp_deeply($result, { artist => 'AC&DC' }, '&amp; unescaped in parsed value')
		or diag(explain($result));

	return EXIT_SUCCESS;
}

package main; ## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;
exit(MKV_parseTagXml_Tests->new->run);
