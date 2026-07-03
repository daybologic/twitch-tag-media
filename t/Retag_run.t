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

package Retag_run_Tests;
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use Daybo::Twitch::Retag;
use Daybo::Twitch::TagWrap;
use English qw(-no_match_vars);
use File::Temp qw(tempdir);
use IO::File;
use POSIX qw(EXIT_FAILURE EXIT_SUCCESS);
use Test::More 0.96;

sub setUp {
	my ($self) = @_;

	$self->sut(Daybo::Twitch::Retag->new());

	return EXIT_SUCCESS;
}

sub testInterruptDuringCollectionExitsBeforeTagging {
	my ($self) = @_;
	plan tests => 4;

	my $dir = tempdir(CLEANUP => 1);
	my $first = sprintf(
	    '%s (live) 2021-10-18 11_05-%d.mp3',
	    $self->uniqueStr(),
	    $self->unique(),
	);
	my $second = sprintf(
	    '%s (live) 2021-10-18 11_06-%d.mp3',
	    $self->uniqueStr(),
	    $self->unique(),
	);
	foreach my $filename ($first, $second) {
		my $path = "$dir/$filename";
		my $fh = IO::File->new($path, '>')
		    or die("Cannot create '$path': $ERRNO");
		print {$fh} $self->uniqueStr();
		$fh->close()
		    or die("Cannot close '$path': $ERRNO");
	}

	my $supportedCalls = 0;
	$self->mock('Daybo::Twitch::Logger', 'emit');
	$self->mock('Daybo::Twitch::TagWrap', 'isExtSupported', sub {
		$supportedCalls++;
		kill('INT', $PID) if ($supportedCalls == 1);
		return 1;
	});
	$self->mock('Daybo::Twitch::Retag', '__tag');

	my $result = $self->sut->run($dir);
	my @logMessages = map { $_->[1] } @{ $self->mockCalls('Daybo::Twitch::Logger', 'emit') };

	is($result, EXIT_FAILURE, 'returns failure after interrupt');
	is($supportedCalls, 1, 'stops collecting after one signal');
	is(scalar(@{ $self->mockCalls('Daybo::Twitch::Retag', '__tag') }), 0, 'does not tag partial collection');
	ok(grep({ $_ =~ m/Caught SIGINT; exiting/ } @logMessages), 'logs immediate exit');

	return EXIT_SUCCESS;
}

package main; ## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;
exit(Retag_run_Tests->new->run);
