#!/usr/bin/perl
# Twitch media tagger.

package OpenAI_identify_Tests;
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use Daybo::Twitch::OpenAI;
use Daybo::Twitch::Retag;
use English qw(-no_match_vars);
use JSON::PP qw(decode_json encode_json);
use Log::Log4perl qw(:levels);
use POSIX qw(EXIT_SUCCESS);
use Test::More 0.96;
use utf8;

sub setUp {
	my ($self) = @_;
	Daybo::Twitch::Retag->new(logLevel => 'TRACE');
	$self->sut(Daybo::Twitch::OpenAI->new());
	return EXIT_SUCCESS;
}

sub tearDown {
	my ($self) = @_;
	$self->clearMocks();
	return EXIT_SUCCESS;
}

sub testSuccess {
	my ($self) = @_;
	plan tests => 8;

	$self->mock('Daybo::Twitch::Logger', 'emit');
	$self->mock('HTTP::Tiny', 'post', sub {
		my (undef, $url, $options) = @_;
		is($url, 'https://api.openai.com/v1/chat/completions', 'posts to Chat Completions');
		like($options->{headers}{authorization}, qr/^Bearer key$/, 'sends API key as bearer token');
		my $request = decode_json($options->{content});
		is($request->{model}, 'gpt-test', 'sends selected model');
		is($request->{response_format}{json_schema}{name}, 'media_metadata', 'requests metadata schema');
		my $context = decode_json($request->{messages}[1]{content});
		is($context->{filename}, 'DJ Tiësto Mix.mp3', 'preserves Unicode in request context');
		return {
			success => 1,
			content => '{"choices":[{"message":{"content":"{\\"title\\":\\"DJ Ti\\u00ebsto Mix\\"}"}}]}',
		};
	});

	my $result = $self->sut->identify('DJ Tiësto Mix.mp3', { creator => 'Someone' }, 'gpt-test', 'key');
	is($result->{title}, 'DJ Tiësto Mix', 'decodes Unicode structured metadata');
	my @trace = grep({ $_->[0] == $TRACE } @{ $self->mockCalls('Daybo::Twitch::Logger', 'emit') });
	is($trace[0][1]{process}{type}, 'model_request', 'logs the actual request at TRACE');
	is($trace[1][1]{process}{type}, 'model_response', 'logs the actual response at TRACE');

	return EXIT_SUCCESS;
}

sub testHttpFailureReturnsDetail {
	my ($self) = @_;
	plan tests => 2;

	$self->mock('HTTP::Tiny', 'post', sub {
		return {
			success => 0,
			status => 401,
			reason => 'Unauthorized',
			content => '{"error":{"message":"invalid api key"}}',
		};
	});

	my ($result, $error) = $self->sut->identify('file.mp4', {}, 'gpt-test', 'key');
	is($result, undef, 'returns no metadata on HTTP failure');
	is($error, 'HTTP 401 Unauthorized: {"error":{"message":"invalid api key"}}', 'returns HTTP failure detail');

	return EXIT_SUCCESS;
}

package main; ## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;
exit(OpenAI_identify_Tests->new->run);
