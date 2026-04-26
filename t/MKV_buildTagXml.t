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

package MKV_buildTagXml_Tests;
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use Daybo::Twitch::TagWrap::Backend::MKV;
use English qw(-no_match_vars);
use POSIX qw(EXIT_SUCCESS);
use Test::More 0.96;

sub setUp {
	my ($self) = @_;

	$self->sut(Daybo::Twitch::TagWrap::Backend::MKV->new());

	return EXIT_SUCCESS;
}

sub testSkipsEmpty {
	my ($self) = @_;
	plan tests => 1;

	my $xml = Daybo::Twitch::TagWrap::Backend::MKV::__buildTagXml(
		$self->uniqueStr(), $self->uniqueStr(), $self->uniqueStr(), $self->unique(), '',
	);
	unlike($xml, qr/<Name>COMMENT/, 'empty comment omitted from XML');

	return EXIT_SUCCESS;
}

sub testSkipsUndefined {
	my ($self) = @_;
	plan tests => 1;

	my $xml = Daybo::Twitch::TagWrap::Backend::MKV::__buildTagXml(
		$self->uniqueStr(), $self->uniqueStr(), $self->uniqueStr(), undef, $self->uniqueStr(),
	);
	unlike($xml, qr/<Name>DATE_RELEASED/, 'undef year omitted from XML');

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

	my $expected = qq{<?xml version="1.0" encoding="UTF-8"?>\n};
	$expected   .= qq{<!DOCTYPE Tags SYSTEM "matroskatags.dtd">\n};
	$expected   .= "<Tags>\n<Tag>\n<Targets/>\n";
	$expected   .= "<Simple><Name>ALBUM</Name><String>${album}</String></Simple>\n";
	$expected   .= "<Simple><Name>ARTIST</Name><String>${artist}</String></Simple>\n";
	$expected   .= "<Simple><Name>COMMENT</Name><String>${comment}</String></Simple>\n";
	$expected   .= "<Simple><Name>TITLE</Name><String>${track}</String></Simple>\n";
	$expected   .= "<Simple><Name>DATE_RELEASED</Name><String>${year}</String></Simple>\n";
	$expected   .= "</Tag>\n</Tags>\n";

	my $xml = Daybo::Twitch::TagWrap::Backend::MKV::__buildTagXml(
		$artist, $album, $track, $year, $comment,
	);
	is($xml, $expected, 'correct XML produced for all fields');

	return EXIT_SUCCESS;
}

sub testXmlEscape {
	my ($self) = @_;
	plan tests => 1;

	my $prefix = $self->uniqueStr();
	my $suffix = $self->uniqueStr();
	my $xml = Daybo::Twitch::TagWrap::Backend::MKV::__buildTagXml(
		"${prefix}&${suffix}", $self->uniqueStr(), $self->uniqueStr(), $self->unique(), $self->uniqueStr(),
	);
	like($xml, qr{<String>\Q$prefix\E&amp;\Q$suffix\E</String>},
		'& in artist value escaped to &amp; in XML');

	return EXIT_SUCCESS;
}

package main; ## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;
exit(MKV_buildTagXml_Tests->new->run);
