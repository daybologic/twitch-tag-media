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

package Retag_printStats_Tests;
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use Daybo::Twitch::Retag;
use English qw(-no_match_vars);
use Log::Log4perl qw(:levels);
use POSIX qw(EXIT_SUCCESS);
use Test::Deep qw(cmp_deeply shallow);
use Test::More 0.96;

sub tearDown {
	my ($self) = @_;
	$self->clearMocks();
	return EXIT_SUCCESS;
}

sub testDisabled {
	my ($self) = @_;
	plan tests => 1;

	my $sut = Daybo::Twitch::Retag->new(stats => 0);
	$self->mock('Daybo::Twitch::Retag', '__log', sub { return });

	$sut->__printStats();

	my $calls = $self->mockCallsWithObject('Daybo::Twitch::Retag', '__log');
	cmp_deeply($calls, [], 'does not log when stats are disabled');

	return EXIT_SUCCESS;
}

sub testSuccess {
	my ($self) = @_;
	plan tests => 1;

	my $sut = Daybo::Twitch::Retag->new(stats => 1, json => 1, jobs => 3);
	$sut->_stats({
		total_files       => 2,
		modified_files    => 1,
		skipped_files     => 1,
		total_bytes       => 2 * 1024 * 1024,
		modified_bytes    => 1024,
		skipped_bytes     => 2048,
		tags_altered      => 4,
		unqualified_bytes => 8,
		unqualified_files => 2,
		seen_files        => 4,
		seen_bytes        => 4096,
		start_time        => 10,
		end_time          => 20,
	});
	$self->mock('Daybo::Twitch::Retag', '__log', sub { return });

	$sut->__printStats();

	my $calls = $self->mockCallsWithObject('Daybo::Twitch::Retag', '__log');
	cmp_deeply($calls, [[
		shallow($sut),
		$INFO,
		{
			process => { type => 'stats' },
			stats => {
				total_files         => 2,
				modified_files      => 1,
				skipped_files       => 1,
				total_bytes         => 2 * 1024 * 1024,
				modified_bytes      => 1024,
				skipped_bytes       => 2048,
				tags_altered        => 4,
				unqualified_bytes   => 8,
				unqualified_files   => 2,
				seen_files          => 4,
				seen_bytes          => 4096,
				elapsed_s           => 10,
				avg_time_per_file_s => 5,
				avg_time_per_mib_s  => 5,
			},
		},
	]], 'logs JSON stats event') or diag(explain($calls));

	return EXIT_SUCCESS;
}

package main; ## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;
exit(Retag_printStats_Tests->new->run);
