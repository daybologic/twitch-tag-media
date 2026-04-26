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

package MKV_xmlEscape_Tests;
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use Daybo::Twitch::TagWrap::Backend::MKV;
use POSIX qw(EXIT_SUCCESS);
use Test::More 0.96;

sub setUp {
	my ($self) = @_;

	$self->sut(Daybo::Twitch::TagWrap::Backend::MKV->new());

	return EXIT_SUCCESS;
}

sub testAmp {
	my ($self) = @_;
	plan tests => 1;

	my $prefix = $self->uniqueStr();
	my $suffix = $self->uniqueStr();
	my $result = Daybo::Twitch::TagWrap::Backend::MKV::__xmlEscape("${prefix}&${suffix}");
	is($result, "${prefix}&amp;${suffix}", '& escaped to &amp;');

	return EXIT_SUCCESS;
}

sub testGt {
	my ($self) = @_;
	plan tests => 1;

	my $prefix = $self->uniqueStr();
	my $suffix = $self->uniqueStr();
	my $result = Daybo::Twitch::TagWrap::Backend::MKV::__xmlEscape("${prefix}>${suffix}");
	is($result, "${prefix}&gt;${suffix}", '> escaped to &gt;');

	return EXIT_SUCCESS;
}

sub testLt {
	my ($self) = @_;
	plan tests => 1;

	my $prefix = $self->uniqueStr();
	my $suffix = $self->uniqueStr();
	my $result = Daybo::Twitch::TagWrap::Backend::MKV::__xmlEscape("${prefix}<${suffix}");
	is($result, "${prefix}&lt;${suffix}", '< escaped to &lt;');

	return EXIT_SUCCESS;
}

sub testOrdering {
	my ($self) = @_;
	plan tests => 1;

	my $result = Daybo::Twitch::TagWrap::Backend::MKV::__xmlEscape('&lt;');
	is($result, '&amp;lt;', '& in &lt; is escaped to &amp; before < is processed');

	return EXIT_SUCCESS;
}

sub testPassthrough {
	my ($self) = @_;
	plan tests => 1;

	my $str = $self->uniqueStr();
	my $result = Daybo::Twitch::TagWrap::Backend::MKV::__xmlEscape($str);
	is($result, $str, 'string with no special characters is returned unchanged');

	return EXIT_SUCCESS;
}

sub testQuot {
	my ($self) = @_;
	plan tests => 1;

	my $prefix = $self->uniqueStr();
	my $suffix = $self->uniqueStr();
	my $result = Daybo::Twitch::TagWrap::Backend::MKV::__xmlEscape("${prefix}\"${suffix}");
	is($result, "${prefix}&quot;${suffix}", '" escaped to &quot;');

	return EXIT_SUCCESS;
}

package main; ## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;
exit(MKV_xmlEscape_Tests->new->run);
