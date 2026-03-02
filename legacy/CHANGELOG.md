# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [5.0.0] - 2026-03-02

### Changed

- Replace twitter gem dependency with x gem (~> 0.19)
- Bump required Ruby version to >= 3.2

### Removed

- Remove local path override for x gem from Gemfile

## [4.2.0] - 2025-04-30

### Changed

- Update x gem dependency to ~> 0.19
- Update for Ruby 3.4 compatibility
- Use `Hash#slice` instead of `select`
- Specify RuboCop plugins instead of require

### Removed

- Drop support for Ruby 3.1

## [4.1.1] - 2024-04-30

### Fixed

- Fix bug in bash.rake task

## [4.1.0] - 2024-04-30

### Changed

- Update x gem dependency to ~> 0.14
- Update geokit dependency to ~> 1.14
- Update launchy dependency to ~> 3.0
- Update thor dependency to ~> 1.3
- Update oauth dependency to ~> 1.1
- Use `filter_map` instead of `collect...compact`
- Use `match?` instead of `=~` when MatchData is not used
- Use `#key?` instead of `#keys.include?`
- Favor `unless` over `if` for negative conditions

### Added

- Add rubocop-performance

### Removed

- Drop support for Ruby 3.0
- Remove coveralls dependency

## [4.0.0] - 2023-04-30

### Changed

- Replace twitter gem with x gem (~> 0.8)
- Update retryable dependency to ~> 3.0
- Extensive RuboCop compliance improvements
- `Twitter::Rest::Client#user` now uses GET instead of POST
- Extract layout from style

### Added

- Add rb-readline dependency

### Removed

- Drop support for Ruby < 3.0
- Remove bundler development dependency

## [3.1.0] - 2016-12-24

### Changed

- Update oauth dependency to ~> 0.5.1
- Update Bash completion

## [3.0.0] - 2016-12-07

### Changed

- Upgrade twitter dependency to ~> 6.0
- Update help text for trends

### Added

- Add support for Ruby 2.3.1

### Removed

- Drop support for Ruby 1.9.3

## [2.10.0] - 2016-01-24

### Added

- Add `muted` command
- Support attaching files to replies

### Changed

- Update twitter dependency to ~> 5.16
- Update Bash and Zsh completions
- Make list output flush so it can be piped

## [2.9.0] - 2015-01-20

### Added

- Implement identicons (enabled with `-C icon`)
- Print a friendly error when running `whoami` without authorizing first

### Changed

- Update twitter dependency to ~> 5.13
- Update retryable dependency to ~> 2.0
- Rename `Twitter::REST::Client::ENDPOINT` to `Twitter::REST::Client::BASE_URL`
- Rename `Twitter::Status` to `Twitter::Tweet`
- Moved `remove_account` to subcommand `delete account`

### Removed

- Require Ruby 1.9.3 or higher

## [2.8.0] - 2014-10-30

### Added

- Support attaching files to replies
- Add `muted` command
- Add `does_follow` check for self and same user

### Changed

- Update twitter dependency to ~> 5.12
- Make list output flush for piping

### Removed

- Remove `--no-retweets` and `--no-replies` flags from streaming subcommands

## [2.7.0] - 2014-06-20

### Changed

- Update twitter dependency to ~> 5.11
- Update rspec test dependency to >= 3

### Fixed

- Fix typo in ruler option description

## [2.6.0] - 2014-05-14

### Added

- Implement `mute`/`unmute` commands
- More accurate reach calculation

### Changed

- Update twitter dependency to ~> 5.9
- Use predicate methods with question marks

### Fixed

- Prevent runaway search results

## [2.5.0] - 2014-03-10

### Added

- Add `--no-replies` flag to all streaming methods
- Add `--no-retweets` flag to all streaming methods

### Changed

- Update twitter dependency to ~> 5.8
- Improve matrix output

## [2.4.0] - 2014-02-14

### Added

- Add `whoami` command
- Add option to stream a list timeline
- Add `--decode-uris` flag to all streaming methods
- Bash autocomplete for options and args

### Changed

- Update twitter dependency to ~> 5.7

## [2.3.0] - 2014-01-26

### Added

- Add `retweets_of_me` command
- Add relative dates option to more commands
- Add `intersection` and `followings_following` commands

### Changed

- Update twitter dependency to ~> 5.6
- Open a user's Twitter profile, not their website

### Fixed

- Remove self from reply all
- Don't pluralize "seconds" if there is only 1 second remaining

## [2.2.1] - 2014-01-10

### Added

- Add `--decode-uris` flag to all timeline methods
- Add support for Ruby 2.1.0

### Changed

- Update twitter dependency to ~> 5.5
- Make `does_follow` method multithreaded

### Fixed

- Fix bug in user streams
- Fix bug in streaming search

## [2.2.0] - 2013-12-24

### Changed

- Update for new search interface

## [2.1.0] - 2013-12-17

### Added

- Implement `--relative-dates` CLI flag

### Changed

- Update twitter dependency to ~> 5.3
- Update retryable dependency to ~> 1.3
- Update oauth dependency to ~> 0.4.7
- Update geokit dependency to ~> 1.7
- Update launchy dependency to ~> 2.4

## [2.0.2] - 2013-12-14

### Added

- Add RuboCop for code quality enforcement
- Enforce code coverage minimums

### Changed

- Only stream Tweets (filter non-tweet events)
- Update screenshots

## [2.0.1] - 2013-11-28

### Fixed

- Fix comparison of `Twitter::NullObject` with `Time`

## [2.0.0] - 2013-11-19

### Added

- Add `--max-id` and `--since-id` flags to favorites command
- Add location support with latitude and longitude
- Add streaming support

### Changed

- Update for twitter gem v5.0.0
- Convert to Ruby 1.9 hash syntax
- Strip newline characters from bios in long format
- Move `members` under the `list` subcommand
- Refactor `T::Editor`

### Removed

- Remove fastercsv dependency
- Require Ruby 1.9.2 or higher

## [1.7.2] - 2013-05-04

### Added

- Add `--max-id` option to timelines
- Add Coveralls for code coverage reporting

### Fixed

- Revert Bash completion due to errors

## [1.7.1] - 2013-02-10

### Added

- Add official support for Ruby 2.0.0
- Add cryptographic signature for gem verification

## [1.7.0] - 2013-02-02

### Added

- Add `--color` option (replacing `--no-color`)
- Add Zsh tab completion script
- Include last Tweet for `list members` command
- Display seconds until rate limit resets

### Changed

- Fetch timeline since last Tweet
- Don't trim user when name is being displayed
- Move development dependencies into Gemfile

## [1.6.0] - 2012-12-16

### Added

- Add `--long` flag to `status` and `whois` commands

## [1.5.1] - 2012-12-08

### Changed

- Update twitter dependency to ~> 4.4

## [1.5.0] - 2012-11-20

### Added

- Add `decode_urls` option to search and timeline commands
- Implement `matrix` as a delegator

### Changed

- Update twitter dependency to ~> 4.2
- Use `count` parameter with all queries

## [1.4.0] - 2012-10-17

### Added

- Add favorite and reply counts to `status` command

### Changed

- Improve JSON parsing performance with OJ

### Fixed

- Display correct status IDs to delete

## [1.3.1] - 2012-10-16

### Changed

- Updates for API v1.1
- Convert specs to new RSpec expectation syntax

## [1.3.0] - 2012-10-07

### Changed

- Handle new API v1.1 list response format

## [1.2.0] - 2012-09-26

### Added

- Add streaming support for timeline, users, and search methods
- Add `sort` option to `trend_locations` method

### Changed

- Update specs for Twitter API v1.1
- Rename `status` to `Tweet`

### Removed

- Remove `suggest` task, `rate_limit` task, and media endpoint

## [1.1.1] - 2012-09-06

### Fixed

- Fix typo `trends_locations` -> `trend_locations`

## [1.1.0] - 2012-08-26

### Added

- Add support for images
- Add indentation option to `ruler`
- Add support for partial matches when setting username

## [1.0.1] - 2012-08-14

### Fixed

- Don't use Ruby keyword as method name

## [1.0.0] - 2012-08-14

### Added

- Add optional user argument to `retweets` and `favorites`
- Display and allow sorting by last Tweet time
- Add `change sort` flag to enum

### Changed

- Update twitter dependency to ~> 3.4
- Merge `T::FormatHelper` and `T::RequestHelpers` into `T::Utils`
- Rewrite authorization copy with interactive setup
- Update tweetstream dependency to version 2.0

### Removed

- Remove remaining dependency on activesupport
- Remove twitter-text dependency

## [0.9.9] - 2012-05-25

### Changed

- Pass `Twitter::List` object directly to `#list_destroy` method
- Don't lazy-require oauth or twitter since they are required for error handling

## [0.9.8] - 2012-05-23

### Changed

- Autoload all classes
- Simplify `distance_of_time_in_words_to_now`

### Fixed

- Fix max collect ID when API returns fewer results than expected

## [0.9.7] - 2012-05-20

### Added

- Add long formatting to streaming commands
- Show relative time

### Changed

- Update twitter gem dependency
- Use `Twitter::Status#full_text` instead of `Twitter::Status#text`

### Removed

- Remove dependency on Action View
- Remove dependency on activesupport

### Fixed

- Fix bug in undo instructions
- Fix tests in timezones other than PST

## [0.9.6] - 2012-05-07

### Added

- Add `user search` command
- Add `rate_limit` command
- Create top-level alias for `T::Stream#matrix`

### Changed

- Factor common methods for printing and formatting

## [0.9.5] - 2012-05-06

### Added

- Add support for getting more than 200 results from multiple APIs

### Changed

- Lazy require geokit and launchy

## [0.9.4] - 2012-05-02

### Changed

- Lazy require twitter-text

## [0.9.3] - 2012-05-01

### Fixed

- Fix bug in CSV streaming output

## [0.9.2] - 2012-05-01

### Added

- Add `--csv` option to stream commands
- Use tweetstream gem

## [0.9.1] - 2012-05-01

### Changed

- Show last 20 results before starting to stream

## [0.9.0] - 2012-05-01

### Added

- Add `search list` command
- Add streaming to timeline method

### Changed

- Rename streaming commands
- Decode HTML entities
- Make search formatting consistent with other status formatting
- Move authorization code into a module

### Removed

- Remove date from status formatting

## [0.8.3] - 2012-04-29

### Changed

- Replace paging with cursoring

## [0.8.2] - 2012-04-29

### Changed

- Truncate unpiped table output so it never wraps

## [0.8.1] - 2012-04-28

### Fixed

- Make no-color output consistent with color output
- Fix typo

## [0.8.0] - 2012-04-27

### Added

- Colored timeline output

### Changed

- Rename default profile to active profile
- Write `~/.rcfile` with correct permissions

## [0.7.0] - 2012-04-26

### Added

- Add `lists` command
- Add CSV output flag for information views
- Add `list information` command
- Add `does_contain` and `does_follow` commands
- Add `trends` and `trend_locations` commands
- Add `reply --all` flag
- Add 140-character `ruler`
- Add `--status` and `--id` flags
- Add aliases for British English

### Changed

- Rename `--dry_run` flag to `--display_url`
- Allow user to specify list by ID instead of slug
- Rename `--created` flag to `--posted`
- Delimit lists from owners with slash

## [0.6.4] - 2012-04-24

### Added

- Add follow roulette

### Changed

- Remove commas from IDs
- Clean up output formatting

## [0.6.3] - 2012-04-24

### Added

- Add `disciples` method (followers minus friends)

### Changed

- More consistent use of @ signs
- Don't trim user when fetching status to reply to

## [0.6.2] - 2012-04-24

### Changed

- Don't depend on Git to list files

## [0.6.1] - 2012-04-24

### Changed

- Make formatting more consistent

## [0.6.0] - 2012-04-24

### Added

- Add `status` method

### Changed

- Update `status` and `whois` formatting
- Add commas to all numbers
- Update delete DM command to take IDs
- Update twitter dependency to version 2.2.3

## [0.5.1] - 2012-04-22

### Added

- Display listed count

## [0.5.0] - 2012-04-22

### Changed

- Major refactoring for version 0.5

### Removed

- Remove JRuby support

## [0.4.0] - 2012-03-30

### Added

- Add method to search mentions, favorites, and retweets
- Add `retweets` method

### Changed

- Use OJ instead of YAJL for fast JSON parsing
- Factor request methods and constants into module

### Removed

- Remove REE support

## [0.3.1] - 2012-01-28

### Added

- Add ID to `whois` output

### Changed

- Update twitter dependency to version 2.1
- Set location off by default
- Replace `run_pager` method with pager gem

## [0.3.0] - 2012-01-02

### Changed

- Replace custom retryable implementation with gem
- Move collection into a module and use recursion
- Retry 3 times when Twitter is down
- Allow user to pass number to DM methods
- Make search methods multithreaded
- Move search into its own namespace
- Flatten namespace by one level

## [0.2.1] - 2011-12-26

### Changed

- Perform iterations of Twitter API requests in separate threads

## [0.2.0] - 2011-12-18

### Added

- Add methods for bulk list deletion and addition
- Add method for list timeline
- Add methods to add/remove users to/from a list
- Add method to create/delete a list
- Add method to follow/unfollow all members of a list
- Add `follow`/`unfollow all` commands
- Add `search` and `favorites` support

### Changed

- Rename `user_name` to `screen_name`
- Always exclude entities
- Move `follow` and `unfollow` into subcommands

## [0.1.0] - 2011-12-10

### Added

- Add the ability to delete statuses and direct messages
- Add git-style automatic paging
- Add support for alternative Ruby implementations
- Add simplecov for test coverage

### Changed

- Remove Active Support dependency and add Ruby 1.8 compatibility
- Convert all tests to RSpec
- Improve error handling
- Strip at-signs from usernames
- Indicate which account created a Tweet or Direct Message
- Move `unfavorite` and `unblock` into `delete` subcommand

## [0.0.2] - 2011-12-02

### Added

- Alias `favorite` to `fave`

### Changed

- Bubble up error messages from the twitter gem
- Allow switching of accounts with just username
- Require yajl for faster JSON parsing

## [0.0.1] - 2011-11-22

### Added

- Initial release

[5.0.0]: https://github.com/sferik/t-ruby/compare/v4.2.0...v5.0.0
[4.2.0]: https://github.com/sferik/t-ruby/compare/v4.1.1...v4.2.0
[4.1.1]: https://github.com/sferik/t-ruby/compare/v4.1.0...v4.1.1
[4.1.0]: https://github.com/sferik/t-ruby/compare/v4.0.0...v4.1.0
[4.0.0]: https://github.com/sferik/t-ruby/compare/v3.1.0...v4.0.0
[3.1.0]: https://github.com/sferik/t-ruby/compare/v3.0.0...v3.1.0
[3.0.0]: https://github.com/sferik/t-ruby/compare/v2.10.0...v3.0.0
[2.10.0]: https://github.com/sferik/t-ruby/compare/v2.9.0...v2.10.0
[2.9.0]: https://github.com/sferik/t-ruby/compare/v2.8.0...v2.9.0
[2.8.0]: https://github.com/sferik/t-ruby/compare/v2.7.0...v2.8.0
[2.7.0]: https://github.com/sferik/t-ruby/compare/v2.6.0...v2.7.0
[2.6.0]: https://github.com/sferik/t-ruby/compare/v2.5.0...v2.6.0
[2.5.0]: https://github.com/sferik/t-ruby/compare/v2.4.0...v2.5.0
[2.4.0]: https://github.com/sferik/t-ruby/compare/v2.3.0...v2.4.0
[2.3.0]: https://github.com/sferik/t-ruby/compare/v2.2.1...v2.3.0
[2.2.1]: https://github.com/sferik/t-ruby/compare/v2.2.0...v2.2.1
[2.2.0]: https://github.com/sferik/t-ruby/compare/v2.1.0...v2.2.0
[2.1.0]: https://github.com/sferik/t-ruby/compare/v2.0.2...v2.1.0
[2.0.2]: https://github.com/sferik/t-ruby/compare/v2.0.1...v2.0.2
[2.0.1]: https://github.com/sferik/t-ruby/compare/v2.0.0...v2.0.1
[2.0.0]: https://github.com/sferik/t-ruby/compare/v1.7.2...v2.0.0
[1.7.2]: https://github.com/sferik/t-ruby/compare/v1.7.1...v1.7.2
[1.7.1]: https://github.com/sferik/t-ruby/compare/v1.7.0...v1.7.1
[1.7.0]: https://github.com/sferik/t-ruby/compare/v1.6.0...v1.7.0
[1.6.0]: https://github.com/sferik/t-ruby/compare/v1.5.1...v1.6.0
[1.5.1]: https://github.com/sferik/t-ruby/compare/v1.5.0...v1.5.1
[1.5.0]: https://github.com/sferik/t-ruby/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/sferik/t-ruby/compare/v1.3.1...v1.4.0
[1.3.1]: https://github.com/sferik/t-ruby/compare/v1.3.0...v1.3.1
[1.3.0]: https://github.com/sferik/t-ruby/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/sferik/t-ruby/compare/v1.1.1...v1.2.0
[1.1.1]: https://github.com/sferik/t-ruby/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/sferik/t-ruby/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/sferik/t-ruby/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/sferik/t-ruby/compare/v0.9.9...v1.0.0
[0.9.9]: https://github.com/sferik/t-ruby/compare/v0.9.8...v0.9.9
[0.9.8]: https://github.com/sferik/t-ruby/compare/v0.9.7...v0.9.8
[0.9.7]: https://github.com/sferik/t-ruby/compare/v0.9.6...v0.9.7
[0.9.6]: https://github.com/sferik/t-ruby/compare/v0.9.5...v0.9.6
[0.9.5]: https://github.com/sferik/t-ruby/compare/v0.9.4...v0.9.5
[0.9.4]: https://github.com/sferik/t-ruby/compare/v0.9.3...v0.9.4
[0.9.3]: https://github.com/sferik/t-ruby/compare/v0.9.2...v0.9.3
[0.9.2]: https://github.com/sferik/t-ruby/compare/v0.9.1...v0.9.2
[0.9.1]: https://github.com/sferik/t-ruby/compare/v0.9.0...v0.9.1
[0.9.0]: https://github.com/sferik/t-ruby/compare/v0.8.3...v0.9.0
[0.8.3]: https://github.com/sferik/t-ruby/compare/v0.8.2...v0.8.3
[0.8.2]: https://github.com/sferik/t-ruby/compare/v0.8.1...v0.8.2
[0.8.1]: https://github.com/sferik/t-ruby/compare/v0.8.0...v0.8.1
[0.8.0]: https://github.com/sferik/t-ruby/compare/v0.7.0...v0.8.0
[0.7.0]: https://github.com/sferik/t-ruby/compare/v0.6.4...v0.7.0
[0.6.4]: https://github.com/sferik/t-ruby/compare/v0.6.3...v0.6.4
[0.6.3]: https://github.com/sferik/t-ruby/compare/v0.6.2...v0.6.3
[0.6.2]: https://github.com/sferik/t-ruby/compare/v0.6.1...v0.6.2
[0.6.1]: https://github.com/sferik/t-ruby/compare/v0.6.0...v0.6.1
[0.6.0]: https://github.com/sferik/t-ruby/compare/v0.5.1...v0.6.0
[0.5.1]: https://github.com/sferik/t-ruby/compare/v0.5.0...v0.5.1
[0.5.0]: https://github.com/sferik/t-ruby/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/sferik/t-ruby/compare/v0.3.1...v0.4.0
[0.3.1]: https://github.com/sferik/t-ruby/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/sferik/t-ruby/compare/v0.2.1...v0.3.0
[0.2.1]: https://github.com/sferik/t-ruby/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/sferik/t-ruby/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/sferik/t-ruby/compare/v0.0.2...v0.1.0
[0.0.2]: https://github.com/sferik/t-ruby/compare/v0.0.1...v0.0.2
[0.0.1]: https://github.com/sferik/t-ruby/releases/tag/v0.0.1
