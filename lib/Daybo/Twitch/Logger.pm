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

package Daybo::Twitch::Logger;
use English qw(-no_match_vars);
use IO::Dir;
use IO::File;
use JSON::PP qw(encode_json);
use List::Util qw(shuffle);
use Log::Log4perl qw(get_logger :levels);
use Sys::CPU qw();
use Time::HiRes qw(sleep time);
use Moose;
use POSIX qw(EXIT_FAILURE EXIT_SUCCESS);
use Daybo::Twitch::TagWrap;

sub BUILD {
	my ($self) = @_;

	my $jsonConf = <<'END_JSON_CONF';
log4perl.rootLogger = WARN, JSON
log4perl.appender.JSON = Log::Log4perl::Appender::Screen
log4perl.appender.JSON.stderr = 0
log4perl.appender.JSON.layout = Log::Log4perl::Layout::PatternLayout
log4perl.appender.JSON.layout.ConversionPattern = %m%n
END_JSON_CONF

	my $textConf = <<'END_TEXT_CONF';
log4perl.rootLogger = WARN, SCREEN
log4perl.appender.SCREEN = Log::Log4perl::Appender::ScreenColoredLevels
log4perl.appender.SCREEN.stderr = 0
log4perl.appender.SCREEN.layout = Log::Log4perl::Layout::PatternLayout
log4perl.appender.SCREEN.layout.ConversionPattern = [%d{yyyy-MM-dd HH:mm:ss.SSS}/%X{stamp} %X{pct}] %P %-5p: (%C L%L): %m%n
log4perl.appender.SCREEN.color.TRACE = white
log4perl.appender.SCREEN.color.DEBUG = bright_blue
log4perl.appender.SCREEN.color.INFO  = bright_white
log4perl.appender.SCREEN.color.WARN  = yellow
log4perl.appender.SCREEN.color.ERROR = red
log4perl.appender.SCREEN.color.FATAL = bright_red
END_TEXT_CONF

	my $conf = $self->json ? $jsonConf : $textConf;
	Log::Log4perl->init_once(\$conf);

	$__logger = get_logger('Daybo.Twitch.Retag');
	$__logger->level(Log::Log4perl::Level::to_priority(uc($self->logLevel)));
	Log::Log4perl::MDC->put('stamp', '00:00:00.000');
	Log::Log4perl::MDC->put('pct',   '  0.00%');
	$SIG{__DIE__} = sub { ## no critic (Variables::RequireLocalizedPunctuationVars)
		local $SIG{__DIE__} = 'DEFAULT';
		$self->__log($ERROR, join('', @_)) if (defined($__logger) && !$EXCEPTIONS_BEING_CAUGHT);
		die @_;
	};
	return;
}

=item C<log($level, $msg)>

Single routing point for every log emission in this module.  C<$level>
must be one of the Log4perl priority constants exported by
C<< use Log::Log4perl qw(:levels) >>: C<$TRACE>, C<$DEBUG>, C<$INFO>,
C<$WARN>, C<$ERROR>, or C<$FATAL>.  Returns early when the current
threshold filters the level out.

When C<--json> is active every emission is a JSON Lines object: a hash
ref is shallow-copied and gains a top-level C<level> key (the string
name of the priority) if absent; a scalar is wrapped as
C<< { level => $name, message => $msg } >>.  When C<--json> is not
active a plain scalar is logged as-is and a hash ref is serialised to
JSON.  No return value.

=cut

sub log {
	my ($self, $level, $msg) = @_;

	my $levelName = Log::Log4perl::Level::to_level($level);
	my $isMethod  = 'is_' . lc($levelName);
	return unless ($__logger->$isMethod());

	local $Log::Log4perl::caller_depth = $Log::Log4perl::caller_depth + 1;

	if ($self->json) {
		my $payload;
		if (ref($msg) eq 'HASH') {
			$payload = { %{$msg} };
			$payload->{level} = $levelName unless (exists($payload->{level}));
		} else {
			$payload = { level => $levelName, message => $msg };
		}
		$__logger->log($level, encode_json($payload));
	} elsif (ref($msg) eq 'HASH') {
		$__logger->log($level, encode_json($msg));
	} else {
		$__logger->log($level, $msg);
	}
	return;
}

1;
