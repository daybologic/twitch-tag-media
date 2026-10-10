# Twitch media tagger.
# Copyright (c) 2023-2026, Rev. Duncan Ross Palmer (2E0EOL)
# All rights reserved.

package Daybo::Twitch::OpenAI;
use English qw(-no_match_vars);
use HTTP::Tiny;
use JSON::PP qw(decode_json encode_json);
use Moose;

=item C<identify($filename, $existing, $model, $apiKey)>

Requests generic metadata for C<$filename>, using C<$existing> as context.
Returns a hash ref with optional C<title>, C<creator>, C<collection>, C<year>,
and C<description> fields, or C<undef> when no usable result is available.

=cut

sub identify {
	my ($self, $filename, $existing, $model, $apiKey) = @_;

	my $request = {
		model => $model,
		messages => [
			{
				role => 'system',
				content => 'Identify generic metadata for a media file. Return only the requested JSON object. Do not invent values when the filename and existing metadata do not support them.',
			},
			{
				role => 'user',
				content => encode_json({ filename => $filename, existing => $existing }),
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
	return unless $response->{success};

	my $data = eval { decode_json($response->{content}) };
	return if ($EVAL_ERROR || !ref($data));
	my $content = $data->{choices}[0]{message}{content};
	return unless defined($content);

	my $metadata = eval { decode_json($content) };
	return if ($EVAL_ERROR || ref($metadata) ne 'HASH');
	return scalar(grep { defined($metadata->{$_}) && length($metadata->{$_}) } keys(%{$metadata}))
		? $metadata
		: undef;
}

1;
