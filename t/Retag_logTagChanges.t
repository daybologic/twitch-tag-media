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

package Retag_logTagChanges_Tests;
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use Daybo::Twitch::Retag;
use English qw(-no_match_vars);
use Log::Log4perl qw(:levels);
use POSIX qw(EXIT_SUCCESS);
use Test::Deep qw(cmp_deeply ignore shallow);
use Test::More 0.96;

sub setUp {
	my ($self) = @_;

	$self->sut(Daybo::Twitch::Retag->new(json => 1));

	return EXIT_SUCCESS;
}

sub tearDown {
	my ($self) = @_;
	$self->clearMocks();
	return EXIT_SUCCESS;
}

sub testForcedUnchanged {
	my ($self) = @_;
	plan tests => 2;

	my $file = '/tmp/' . $self->uniqueStr() . '.mp3';
	my %tags = (
		artist  => $self->uniqueStr(),
		album   => $self->uniqueStr(),
		track   => $self->uniqueStr(),
		year    => $self->unique(),
		comment => $self->uniqueStr(),
	);
	$self->mock('Daybo::Twitch::Retag', '__log', sub { return });

	my $count = $self->sut->__logTagChanges($file, 100, \%tags, @tags{qw(artist album track year comment)});

	is($count, 0, 'returns zero when tags are unchanged');
	my $calls = $self->mockCallsWithObject('Daybo::Twitch::Retag', '__log');
	cmp_deeply($calls, [[
		shallow($self->sut),
		$INFO,
		{
			file => $file,
			process => {
				type => 'changelog',
				pct => 100,
				pid => ignore(),
				message => 'Tags unchanged, forced rewrite',
			},
			changes => [],
		},
	]], 'logs forced unchanged JSON event') or diag(explain($calls));

	return EXIT_SUCCESS;
}

sub testSuccess {
	my ($self) = @_;
	plan tests => 2;

	my $file = '/tmp/' . $self->uniqueStr() . '.mp3';
	$self->mock('Daybo::Twitch::Retag', '__log', sub { return });

	my $count = $self->sut->__logTagChanges(
		$file,
		50,
		{ artist => 'Old Artist', album => 'Album', track => '', year => '2020', comment => 'Comment' },
		'New Artist',
		'Album',
		'Track',
		'2021',
		'Comment',
	);

	is($count, 3, 'returns changed field count');
	my $calls = $self->mockCallsWithObject('Daybo::Twitch::Retag', '__log');
	cmp_deeply($calls, [[
		shallow($self->sut),
		$INFO,
		{
			file => $file,
			process => {
				type => 'changelog',
				pct => 50,
				pid => ignore(),
			},
			changes => [
				{ field => 'artist', old => 'Old Artist', new => 'New Artist' },
				{ field => 'track', old => '', new => 'Track' },
				{ field => 'year', old => '2020', new => '2021' },
			],
		},
	]], 'logs changed fields in JSON event') or diag(explain($calls));

	return EXIT_SUCCESS;
}

package main; ## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;
exit(Retag_logTagChanges_Tests->new->run);
