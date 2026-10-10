#!/usr/bin/perl
# Twitch media tagger.

package Retag_aiFallback_FakeBackend;
use strict;
use warnings;

our @calls;

sub readTags {
	my ($self) = @_;
	return {
		artist => 'Existing creator',
		comment => 'Existing description',
	};
}

sub deleteTags {
	my ($self, @args) = @_;
	push(@calls, [ 'deleteTags', $self, @args ]);
	return;
}

sub writeTags {
	my ($self, @args) = @_;
	push(@calls, [ 'writeTags', $self, @args ]);
	return;
}

package Retag_aiFallback_Tests; ## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use Daybo::Twitch::Retag;
use English qw(-no_match_vars);
use File::Temp qw(tempfile);
use POSIX qw(EXIT_SUCCESS);
use Test::More 0.96;

sub setUp {
	my ($self) = @_;
	@Retag_aiFallback_FakeBackend::calls = ();
	$self->sut(Daybo::Twitch::Retag->new(model => 'gpt-test'));
	$self->sut->__originalProgramName($PROGRAM_NAME);
	$self->sut->_stats({ start_time => 0 });
	return EXIT_SUCCESS;
}

sub tearDown {
	my ($self) = @_;
	$self->clearMocks();
	return EXIT_SUCCESS;
}

sub testFallbackMergesGenericMetadata {
	my ($self) = @_;
	plan tests => 6;

	local $ENV{OPENAI_API_KEY} = 'test-key';
	my ($fh, $file) = tempfile(SUFFIX => '.mp4');
	print {$fh} 'media';
	$fh->close() or die("Cannot close '$file': $ERRNO");

	my $backend = bless({}, 'Retag_aiFallback_FakeBackend');
	$self->mock('Daybo::Twitch::TagWrap', 'getBackendForExt', sub { return $backend });
	$self->mock('Daybo::Twitch::OpenAI', 'identify', sub {
		my (undef, $filename, $existing, $model, $key) = @_;
		is($filename, (split(m{/}, $file))[-1], 'basename sent to OpenAI');
		is($existing->{creator}, 'Existing creator', 'existing creator sent to OpenAI');
		is($model, 'gpt-test', 'selected model sent to OpenAI');
		is($key, 'test-key', 'API key sent to OpenAI');
		return {
			title => 'AI title',
			collection => 'AI collection',
			year => '2026',
			description => 'AI description',
		};
	});
	$self->mock('Daybo::Twitch::Retag', '__chown', sub { return 1 });

	$self->sut->__tagPerProcess($file, 'mp4', 50, undef, undef, undef, undef);
	my $write = $Retag_aiFallback_FakeBackend::calls[1];
	is_deeply([ @{$write}[2 .. 7] ], [
		$file, 'Existing creator', 'AI collection', 'AI title', '2026', 'AI description',
	], 'AI metadata is merged into canonical backend fields');
	is($Retag_aiFallback_FakeBackend::calls[0][0], 'deleteTags', 'tags are rewritten');

	return EXIT_SUCCESS;
}

sub testNoModelDoesNotAuthorizeFallback {
	my ($self) = @_;
	plan tests => 1;

	local $ENV{OPENAI_API_KEY} = 'test-key';
	$self->sut(Daybo::Twitch::Retag->new());
	ok(!$self->sut->__aiAuthorized(), 'API key alone does not authorize OpenAI');

	return EXIT_SUCCESS;
}

package main; ## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;
exit(Retag_aiFallback_Tests->new->run);
