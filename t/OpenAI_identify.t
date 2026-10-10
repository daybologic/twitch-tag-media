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
	plan tests => 7;

	$self->mock('Daybo::Twitch::Logger', 'emit');
	$self->mock('HTTP::Tiny', 'post', sub {
		my (undef, $url, $options) = @_;
		is($url, 'https://api.openai.com/v1/chat/completions', 'posts to Chat Completions');
		like($options->{headers}{authorization}, qr/^Bearer key$/, 'sends API key as bearer token');
		my $request = decode_json($options->{content});
		is($request->{model}, 'gpt-test', 'sends selected model');
		is($request->{response_format}{json_schema}{name}, 'media_metadata', 'requests metadata schema');
		return {
			success => 1,
			content => encode_json({
				choices => [ { message => { content => encode_json({ title => 'A title' }) } } ],
			}),
		};
	});

	my $result = $self->sut->identify('file.mp4', { creator => 'Someone' }, 'gpt-test', 'key');
	is($result->{title}, 'A title', 'decodes structured metadata');
	my @trace = grep({ $_->[0] == $TRACE } @{ $self->mockCalls('Daybo::Twitch::Logger', 'emit') });
	is($trace[0][1]{process}{type}, 'openai_request', 'logs the actual request at TRACE');
	is($trace[1][1]{process}{type}, 'openai_response', 'logs the actual response at TRACE');

	return EXIT_SUCCESS;
}

package main; ## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;
exit(OpenAI_identify_Tests->new->run);
