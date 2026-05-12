# Codex CLI Instructions

Use this file as the operating guide for Codex CLI when working in this repository.

## Personal Coding Preferences

- Use tabs rather than spaces in code snippets.
- For Perl scripts, always use `use English qw(-no_match_vars);`.
- Ask before adding new production dependencies.

## Project Overview

`twitch-tag-media` is a Perl utility that reads Twitch stream recording filenames downloaded via `yt-dlp` and writes tags to media files:

- MP3 files: ID3v1/v2 tags via `id3v2`.
- MP4 files: metadata via `ffmpeg`.

The utility processes files concurrently by forking.

## Build And Test Commands

```sh
perl Makefile.PL   # Generate Makefile
make               # Build
make test          # Run tests, parallelised by Sys::CPU
make install       # Install
```

Debian packaging:

```sh
dpkg-buildpackage -b
```

## Architecture

The entry point is `bin/twitch-tag-media`. It instantiates `Daybo::Twitch::Retag` and calls `->run($dir)`.

The main module is `lib/Daybo/Twitch/Retag.pm`, a Moose-based module containing the core logic:

- `run($dirname)` recursively walks directories, skips `@eaDir`, and forks a child for each supported media file.
- `__tag(...)` forks a child process. The parent collects PIDs; the child calls `__tagPerProcess(...)` and exits.
- `__tagPerProcess(...)` reads existing tags and writes new ones through the correct backend.
- `__parseFileName($filename)` extracts artist, album, track, and year from the `yt-dlp` filename convention. It also contains hardcoded artist handle-to-display-name mappings.
- `__acceptableDirName($name)` returns false for `@eaDir` Synology index directories.

Expected album names are generated as `"$artist on Twitch"`.

## Filename Convention

Expected input filename pattern:

```text
ArtistHandle (type) YYYY-MM-DD HH_MM-StreamID.mp3
```

Example:

```text
1stdegreeproductions (live) 2021-10-18 11_05-40110166187.mp3
```

`parseFileName` strips `-trim`, `-tempo`, and `-untempo` suffixes from track names. It normalises artist handles by removing `Official`, `Music`, and `dj`; replacing `_` with a space; trimming whitespace; and applying specific handle-to-display-name mappings.

## Perl Coding Style

- Use cuddled braces for all `sub` definitions: `sub foo {`.
- Do not write `sub foo{`.
- Subroutines prefixed with `__` are private to the module.
- Subroutines without `__`, such as `run` and `usage`, are public API used by `bin/twitch-tag-media`.
- Keep all subroutines in lexical, case-insensitive alphabetical order.
- Ignore the `__` prefix when determining subroutine order.
- Apply the ordering rule when adding or renaming subroutines.
- Always include parentheses when calling subroutines, so method calls remain visually distinct from Moose attribute access.
- Every subroutine, public or private, must have a Pod documentation block immediately preceding it, between the previous `=cut` and the `sub` keyword.
- Always use `use English qw(-no_match_vars);`.
- Use English special variables, such as `$EVAL_ERROR`, `$ERRNO`, and `$CHILD_ERROR`, instead of `$@`, `$!`, and `$?`.

## Code Quality Rules

A pre-commit hook, `maint/trap-goose-corruption.sh`, configured in `.pre-commit-config.yaml`, rejects commits if files under `lib/` contain:

- Markdown fences: ` ``` `
- File path headers, such as `### /path/file`
- Line-number prefixes, such as `123: `

Do not rewrite entire files unless the requested change explicitly requires it. Make minimal, targeted edits that are easy to verify with `git diff`.

After any modification:

- Run `git diff`.
- Confirm only the intended lines changed.
- Do not commit automatically unless explicitly instructed.

## Commit Emoji Conventions

Follow Gitmoji for commit message prefixes. Notable conventions used in this project:

- `⚰️` for removing dead code.
- `➕` for adding a dependency.

## Unit Tests

Tests live in `t/*.t` and use `Test::Module::Runnable`, vendored under `externals/libtest-module-runnable-perl/`. The framework auto-discovers and runs all methods whose names match `^test`.

Each `.t` file defines two packages:

1. A test class, such as `MP3_deleteTags_Tests`, that extends `Test::Module::Runnable`.
2. `package main`, ending with the one-liner `exit(ClassName->new->run)`.

The test class contains:

- `setUp`, which instantiates the system under test into `$self->sut(...)` and returns `EXIT_SUCCESS`.
- One or more `test*` methods. Each test method calls `plan tests => N`, exercises `$self->sut`, and returns `EXIT_SUCCESS`.

All `t/*.t` files must be executable. Set the executable bit on new test files before committing.

## Mocking

External processes, including `id3v2`, `ffmpeg`, and `mkvpropedit`, must never be invoked by unit tests. Mock them at the `_system` boundary.

Mock external calls, such as `_system` on the backend base class, with `$self->mock($package, $method)`. This uses `Test::MockModule` internally and records all calls.

Use:

- `$self->mockCallsWithObject($package, $method)` to retrieve calls as an arrayref of arrayrefs, including `$self` as the first element.
- `$self->mockCalls($package, $method)` when the object reference is not needed.
- `Test::Deep::cmp_deeply` for deep assertions.

## Mocking CORE::open

Perl built-ins cannot be mocked with `Test::MockModule`. To test a seam method that calls bare `open()`, override `CORE::GLOBAL::open` in a `BEGIN` block so the override exists before any module loads:

```perl
our $mockOpen;

BEGIN {
	*CORE::GLOBAL::open = sub (*;$@) {
		if (defined $Package_Tests::mockOpen) {
			return $Package_Tests::mockOpen->(@_);
		}
		return CORE::open($_[0])                       if @_ == 1;
		return CORE::open($_[0], $_[1])                if @_ == 2;
		return CORE::open($_[0], $_[1], @_[2 .. $#_]);
	};
}
```

Rules for this pattern:

- Production seam methods must call bare `open(...)`, not `CORE::open(...)`.
- `CORE::open(...)` bypasses `CORE::GLOBAL::open` and cannot be intercepted.
- The `(*;$@)` prototype is required. Without it, bareword filehandles used by system modules, such as `Cwd`, break under `use strict` when the fallback path runs.
- Do not use `goto &CORE::open` for the fallback. It does not correctly pass bareword filehandle arguments on this platform.
- Dispatch the fallback by arity: `@_ == 1`, `@_ == 2`, or `3+`.
- Use `our $mockOpen` as a package variable.
- Use `local $mockOpen = sub { ... }` inside each test method for automatic restoration.
- Reference the mock via the full package name, such as `$Package_Tests::mockOpen`, inside the `BEGIN` closure.
- In a success mock, `$_[0] = $fake_fh` sets the caller's filehandle variable by alias.
- `tearDown` should `undef $mockOpen` as a safety net.

## Test Data

Use `$self->uniqueStr()` to generate unique, predictable alphanumeric strings for filenames and other inputs. Do not hardcode values where `uniqueStr()` can be used instead.

If the unique value must be an integer, use `$self->unique()`.

## Test Philosophy

Tests are unit-level. Each file covers one method of one class.

The test filename mirrors the production method being tested. For example, `MP3_deleteTags.t` tests `Backend::MP3::deleteTags`.

If the method name is prefixed with any number of underscores, do not include those underscores in the test filename.

The long-term goal is 100% unit test coverage of all possible code paths, one step at a time.

Typical test names:

- `sub testSuccess` for a successful case.
- `sub testFailure` for an error condition.

There may be multiple success cases and multiple failure conditions per method.
