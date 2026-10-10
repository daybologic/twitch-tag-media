# Twitch media tagger.
# Copyright (c) 2023-2026, Rev. Duncan Ross Palmer (2E0EOL)
# All rights reserved.

package Daybo::Twitch::OpenAI;
use English qw(-no_match_vars);
use Encode qw(FB_CROAK decode);
use HTTP::Tiny;
use JSON::PP qw(decode_json encode_json);
use Log::Log4perl qw(:levels);
use Moose;
use utf8 ();
use Daybo::Twitch::BaseObject;
extends 'Daybo::Twitch::BaseObject';

=item C<identify($filename, $existing, $model, $apiKey)>

Requests generic metadata for C<$filename>, using C<$existing> as context.
Returns a hash ref with optional C<title>, C<creator>, C<collection>, C<year>,
and C<description> fields, or C<undef> and an explanatory error string when
no usable result is available.

=cut

sub identify {
	my ($self, $filename, $existing, $model, $apiKey) = @_;
	my $unicodeFilename = $filename;
	$unicodeFilename = eval { decode('UTF-8', $filename, FB_CROAK) }
		unless (utf8::is_utf8($unicodeFilename));
	$unicodeFilename = $filename if ($EVAL_ERROR);
	my %unicodeExisting = map {
		my $value = $existing->{$_};
		$value = eval { decode('UTF-8', $value, FB_CROAK) }
			if (defined($value) && !utf8::is_utf8($value));
		$value = $existing->{$_} if ($EVAL_ERROR);
		($_ => $value);
	} keys(%{$existing});

	my $request = {
		model => $model,
		messages => [
			{
				role => 'system',
				content => 'Identify generic metadata for a media file. Return only the requested JSON object. Do not invent values when the filename and existing metadata do not support them.',
			},
			{
				role => 'user',
				content => encode_json({ filename => $unicodeFilename, existing => \%unicodeExisting }),
			},
		],
		response_format => {
			type => 'json_schema',
			json_schema => {
				name => 'media_metadata',
				strict => JSON::PP::true,
				schema => {
					type => 'object',
					additionalProperties => JSON::PP::false,
					required => [qw(title creator collection year description)],
					properties => {
						title => { anyOf => [ { type => 'string' }, { type => 'null' } ] },
						creator => { anyOf => [ { type => 'string' }, { type => 'null' } ] },
						collection => { anyOf => [ { type => 'string' }, { type => 'null' } ] },
						year => { anyOf => [ { type => 'string' }, { type => 'null' } ] },
						description => { anyOf => [ { type => 'string' }, { type => 'null' } ] },
					},
				},
			},
		},
	};

	$self->logger->emit($TRACE, {
		process => { type => 'model_request' },
		model => $model,
		request => $request,
	});

	my $response = HTTP::Tiny->new(timeout => 60)->post(
		'https://api.openai.com/v1/chat/completions',
		{
			content => encode_json($request),
			headers => {
				'authorization' => "Bearer $apiKey",
				'content-type' => 'application/json',
			},
		},
	);
	$self->logger->emit($TRACE, {
		process => { type => 'model_response' },
		model => $model,
		status => defined($response->{status}) ? $response->{status} + 0 : undef,
		response => $response->{content},
	});
	unless ($response->{success}) {
		my $status = defined($response->{status}) ? $response->{status} : 'unknown';
		my $reason = $response->{reason} // 'request failed';
		my $detail = $response->{content} // '';
		$detail =~ s/\s+/ /g;
		$detail = substr($detail, 0, 1000);
		return (undef, "HTTP $status $reason" . (length($detail) ? ": $detail" : ''));
	}

	my $responseText = $response->{content};
	unless (utf8::is_utf8($responseText)) {
		my $utf8Response = eval { decode('UTF-8', $responseText, FB_CROAK) };
		$responseText = $EVAL_ERROR ? decode('ISO-8859-1', $responseText) : $utf8Response;
	}
	my $data = eval { JSON::PP->new->utf8(0)->decode($responseText) };
	return (undef, "invalid HTTP response JSON: $EVAL_ERROR") if ($EVAL_ERROR || !ref($data));
	my $content = $data->{choices}[0]{message}{content};
	return (undef, 'HTTP response did not contain model content') unless defined($content);

	my $contentText = $content;
	unless (utf8::is_utf8($contentText)) {
		my $utf8Content = eval { decode('UTF-8', $contentText, FB_CROAK) };
		$contentText = $EVAL_ERROR ? decode('ISO-8859-1', $contentText) : $utf8Content;
	}
	my $metadata = eval { JSON::PP->new->utf8(0)->decode($contentText) };
	return (undef, "invalid model response JSON: $EVAL_ERROR") if ($EVAL_ERROR || ref($metadata) ne 'HASH');
	return scalar(grep { defined($metadata->{$_}) && length($metadata->{$_}) } keys(%{$metadata}))
		? $metadata
		: (undef, 'model response contained no usable metadata');
}

1;
