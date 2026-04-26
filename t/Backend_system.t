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

package Backend_system_Tests;
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use Daybo::Twitch::TagWrap::Backend;
use English qw(-no_match_vars);
use File::Spec;
use POSIX qw(EXIT_SUCCESS);
use Test::Deep qw(cmp_deeply);
use Test::Exception;
use Test::More 0.96;

sub setUp {
	my ($self) = @_;

	$self->sut(Daybo::Twitch::TagWrap::Backend->new());

	return EXIT_SUCCESS;
}

sub tearDown {
	my ($self) = @_;
	$self->clearMocks();
	return EXIT_SUCCESS;
}

sub testFailedToRun {
	my ($self) = @_;
	plan tests => 1;

	my $cmd = $self->uniqueStr();

	my ($mockPackage, $mockMethod) = ('Daybo::Twitch::TagWrap::Backend', 'run3');
	$self->mock($mockPackage, $mockMethod, sub { $CHILD_ERROR =-1 });

	throws_ok(
		sub { $self->sut->_system($cmd) },
		qr/Failed to run \Q$cmd\E/,
		'dies when $CHILD_ERROR is -1 (failed to exec)',
	);

	return EXIT_SUCCESS;
}

sub testNonZeroExit {
	my ($self) = @_;
	plan tests => 1;

	my $cmd = $self->uniqueStr();

	my ($mockPackage, $mockMethod) = ('Daybo::Twitch::TagWrap::Backend', 'run3');
	$self->mock($mockPackage, $mockMethod, sub { $CHILD_ERROR =1 << 8 });

	throws_ok(
		sub { $self->sut->_system($cmd) },
		qr/\Q$cmd\E exited with status 1/,
		'dies when command exits non-zero',
	);

	return EXIT_SUCCESS;
}

sub testSignalDeath {
	my ($self) = @_;
	plan tests => 2;

	my $cmd = $self->uniqueStr();

	my ($mockPackage, $mockMethod) = ('Daybo::Twitch::TagWrap::Backend', 'run3');
	$self->mock($mockPackage, $mockMethod, sub { $CHILD_ERROR =2 });

	eval { $self->sut->_system($cmd) };
	like($EVAL_ERROR,   qr/\Q$cmd\E died with signal 2/, 'dies with signal death message');
	unlike($EVAL_ERROR, qr/core dumped/,                 'no core-dump note when bit 7 clear');

	return EXIT_SUCCESS;
}

sub testSignalDeathWithCore {
	my ($self) = @_;
	plan tests => 1;

	my $cmd = $self->uniqueStr();

	my ($mockPackage, $mockMethod) = ('Daybo::Twitch::TagWrap::Backend', 'run3');
	$self->mock($mockPackage, $mockMethod, sub { $CHILD_ERROR =3 | 128 });

	throws_ok(
		sub { $self->sut->_system($cmd) },
		qr/\Q$cmd\E died with signal 3 \(core dumped\)/,
		'dies with signal message including core-dump note',
	);

	return EXIT_SUCCESS;
}

sub testSuccess {
	my ($self) = @_;
	plan tests => 2;

	my $cmd = $self->uniqueStr();
	my $arg = $self->uniqueStr();

	my ($mockPackage, $mockMethod) = ('Daybo::Twitch::TagWrap::Backend', 'run3');
	$self->mock($mockPackage, $mockMethod, sub { $CHILD_ERROR =0 });

	my $result = $self->sut->_system($cmd, $arg);
	is($result, 0, 'returns 0 on clean exit');

	my $calls = $self->mockCallsWithObject($mockPackage, $mockMethod);
	cmp_deeply($calls, [[
		[$cmd, $arg],
		undef,
		File::Spec->devnull(),
		File::Spec->devnull(),
	]], 'run3 called with command arrayref and discarded stdout/stderr')
	    or diag(explain($calls));

	return EXIT_SUCCESS;
}

package main; ## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;
exit(Backend_system_Tests->new->run);
