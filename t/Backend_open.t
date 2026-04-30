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
# INTERRUPTION) WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
# EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

package Backend_open_Tests;
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

our $mockOpen;

# Must be in place before any module loads.  Bare open() (without the CORE::
# prefix) dispatches through CORE::GLOBAL::open at runtime; explicit CORE::open
# does not.  The (*;$@) prototype is required so that bareword filehandles used
# by system modules (e.g. Cwd) continue to work under strict in the fallback
# path.  The fallback dispatches by arity rather than using goto &CORE::open
# because goto does not correctly pass bareword arguments on this platform.
BEGIN {
	*CORE::GLOBAL::open = sub (*;$@) {
		if (defined $Backend_open_Tests::mockOpen) {
			return $Backend_open_Tests::mockOpen->(@_);
		}
		return CORE::open($_[0])                       if @_ == 1;
		return CORE::open($_[0], $_[1])                if @_ == 2;
		return CORE::open($_[0], $_[1], @_[2 .. $#_]);
	};
}

extends 'Test::Module::Runnable';

use Daybo::Twitch::TagWrap::Backend;
use English qw(-no_match_vars);
use POSIX qw(EXIT_SUCCESS);
use Test::Deep qw(cmp_deeply);
use Test::More 0.96;

sub setUp {
	my ($self) = @_;

	$self->sut(Daybo::Twitch::TagWrap::Backend->new());

	return EXIT_SUCCESS;
}

sub tearDown {
	my ($self) = @_;
	undef $mockOpen;
	return EXIT_SUCCESS;
}

sub testFailure {
	my ($self) = @_;
	plan tests => 1;

	local $mockOpen = sub { return 0 };

	my $result = $self->sut->__open('-|', $self->uniqueStr());
	is($result, undef, 'undef returned when open fails');

	return EXIT_SUCCESS;
}

sub testSuccess {
	my ($self) = @_;
	plan tests => 2;

	my $cmd     = $self->uniqueStr();
	my $fake_fh = bless {}, 'FakeFH';
	my @captured;

	local $mockOpen = sub {
		@captured = @_[1 .. $#_];
		$_[0]     = $fake_fh;
		return 1;
	};

	my $result = $self->sut->__open('-|', $cmd);
	is($result, $fake_fh, 'filehandle set by open is returned');
	cmp_deeply(\@captured, ['-|', $cmd], 'open called with correct mode and command')
		or diag(explain(\@captured));

	return EXIT_SUCCESS;
}

package main; ## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;
exit(Backend_open_Tests->new->run);
