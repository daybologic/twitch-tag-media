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

package MKV_writeTags_Tests;
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use Daybo::Twitch::TagWrap::Backend::MKV;
use English qw(-no_match_vars);
use POSIX qw(EXIT_SUCCESS);
use Test::Deep qw(cmp_deeply shallow);
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

sub testSuccess {
	my ($self) = @_;
	plan tests => 3;

	my $file    = $self->uniqueStr();
	my $artist  = $self->uniqueStr();
	my $album   = $self->uniqueStr();
	my $track   = $self->uniqueStr();
	my $year    = $self->unique();
	my $comment = $self->uniqueStr();
	my $xml     = $self->uniqueStr();
	my $temp    = $self->uniqueStr();

	my $captured = '';
	open(my $fake_fh, '>', \$captured) or die("could not open string ref: $ERRNO");

	my $mkvPackage = 'Daybo::Twitch::TagWrap::Backend::MKV';
	$self->mock($mkvPackage, '__buildTagXml', sub { return $xml });
	$self->mock($mkvPackage, 'tempfile', sub { return ($fake_fh, $temp) });
	$self->mock('Daybo::Twitch::TagWrap::Backend', '_system', sub { return 0 });

	$self->sut->writeTags($file, $artist, $album, $track, $year, $comment);

	my $buildCalls = $self->mockCallsWithObject($mkvPackage, '__buildTagXml');
	cmp_deeply($buildCalls, [[$artist, $album, $track, $year, $comment]],
		'__buildTagXml called with correct args') or diag(explain($buildCalls));

	is($captured, $xml, 'XML written to temp file');

	my $systemCalls = $self->mockCallsWithObject('Daybo::Twitch::TagWrap::Backend', '_system');
	cmp_deeply($systemCalls, [[
		shallow($self->sut),
		'mkvpropedit',
		'--tags', "global:${temp}",
		$file,
	]], 'mkvpropedit called with correct args') or diag(explain($systemCalls));

	return EXIT_SUCCESS;
}

package main; ## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;
exit(MKV_writeTags_Tests->new->run);
