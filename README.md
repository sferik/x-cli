# [![Application icon](https://github.com/sferik/t/raw/master/icon/t.png)][icon]
[icon]: https://github.com/sferik/t/raw/master/icon/t.png

# Twitter CLI
[![Gem Version](https://img.shields.io/gem/v/t.svg)][gem]
[![Build Status](https://img.shields.io/travis/sferik/t.svg)][travis]
[![Dependency Status](https://img.shields.io/gemnasium/sferik/t.svg)][gemnasium]
[![Coverage Status](https://img.shields.io/coveralls/sferik/t.svg)][coveralls]
[![tip for next commit](https://tip4commit.com/projects/102.svg)](https://tip4commit.com/github/sferik/t)

[gem]: https://rubygems.org/gems/t
[travis]: https://travis-ci.org/sferik/t
[gemnasium]: https://gemnasium.com/sferik/t
[coveralls]: https://coveralls.io/r/sferik/t

#### A command-line power tool for Twitter.
The CLI takes syntactic cues from the [Twitter SMS commands][sms], but it
offers vastly more commands and capabilities than are available via SMS.

[sms]: https://support.twitter.com/articles/14020-twitter-sms-command

## Dependencies
First, make sure you have Ruby installed.

**On a Mac**, open `/Applications/Utilities/Terminal.app` and type:

    ruby -v

If the output looks something like this, you're in good shape:

    ruby 2.3.1p112 (2016-04-26 revision 54768) [x86_64-darwin15]

If the output looks more like this, you need to [install Ruby][ruby]:

[ruby]: https://www.ruby-lang.org/en/downloads/

    ruby: command not found

**On Linux**, for Debian-based systems, open a terminal and type:

    sudo apt-get install ruby-dev

or for Red Hat-based distros like Fedora and CentOS, type:

    sudo yum install ruby-devel

(if necessary, adapt for your package manager)

**On Windows**, you can install Ruby with [RubyInstaller][rubyinstaller].

[rubyinstaller]: http://rubyinstaller.org/downloads/

## Installation
Once you've verified that Ruby is installed:

    gem install t

## Configuration
Twitter API v1.1 requires OAuth for all of its functionality, so you'll need a
registered Twitter application. If you've never registered a Twitter
application before, it's easy! Just sign-in using your Twitter account and then
fill out the short form at <https://apps.twitter.com/app/new>. If you've
previously registered a Twitter application, it should be listed at
<https://apps.twitter.com/>. Once you've registered an application, make sure
to set your application's Access Level to "Read, Write and Access direct
messages", otherwise you'll receive an error that looks like this:

    Error processing your OAuth request: Read-only application cannot POST

A mobile phone number must be associated with your account in order to obtain write privileges. If your carrier is not supported by Twitter and you are unable to add a number, contact Twitter using <https://support.twitter.com/forms/platform>, selecting the last checkbox. Some users have reported success adding their number using the mobile site, <https://mobile.twitter.com/settings>, which seems to bypass the carrier check at the moment.

Now, you're ready to authorize a Twitter account with your application. To
proceed, type the following command at the prompt and follow the instructions:

    t authorize

This command will direct you to a URL where you can sign-in to Twitter,
authorize the application, and then enter the returned PIN back into the
terminal. If you type the PIN correctly, you should now be authorized to use
`t` as that user. To authorize multiple accounts, simply repeat the last step,
signing into Twitter as a different user.

**NOTE**: If you have problems authorizing multiple accounts, open a new window in your browser in incognito/private-browsing mode and repeat the `t authorize` steps. This is apparently due to a bug in twitter's cookie handling.

You can see a list of all the accounts you've authorized by typing the command:

    t accounts

The output of which will be structured like this:

    sferik
      UDfNTpOz5ZDG4a6w7dIWj
      uuP7Xbl2mEfGMiDu1uIyFN
    gem
      thG9EfWoADtIr6NjbL9ON (active)

**Note**: One of your authorized accounts (specifically, the last one
authorized) will be set as active. To change the active account, use the `set`
subcommand, passing either just a username, if it's unambiguous, or a username
and consumer key pair, like this:

    t set active sferik UDfNTpOz5ZDG4a6w7dIWj

Account information is stored in a YAML-formatted file located at `~/.trc`.

**Note**: Anyone with access to this file can impersonate you on Twitter, so
it's important to keep it secure, just as you would treat your SSH private key.
For this reason, the file is hidden and has the permission bits set to `0600`.

## Usage Examples
Typing `t help` will list all the available commands. You can type `t help
TASK` to get help for a specific command.

    t help

#### Update your status
    t update "I'm tweeting from the command line. Isn't that special?"

**Note**: If your tweet includes special characters (e.g. `!`), make sure to
wrap it in single quotes instead of double quotes, so those characters are not
interpreted by your shell.
If you use single quotes, your Tweet obviously can't contain any
apostrophes unless you prefix them with a backslash `\`:

    t update 'I\'m tweeting from the command line. Isn\'t that special?'

#### Retrieve detailed information about a Twitter user
    t whois @sferik

#### Retrieve stats for multiple users
    t users -l @sferik @gem

#### Follow users
    t follow @sferik @gem

#### Check whether one user follows another
    t does_follow @ev @sferik

**Note**: If the first user does not follow the second, `t` will exit with a
non-zero exit code. This allows you to execute commands conditionally. For
example, here's how to send a user a direct message only if they already follow you:

    t does_follow @ev && t dm @ev "What's up, bro?"

#### Create a list for everyone you're following
    t list create following-`date "+%Y-%m-%d"`

#### Add everyone you're following to that list (up to 500 users)
    t followings | xargs t list add following-`date "+%Y-%m-%d"`

#### List all the members of a list, in long format
    t list members -l following-`date "+%Y-%m-%d"`

#### List all your lists, in long format
    t lists -l

#### List all your friends, in long format, ordered by number of followers
    t friends -l --sort=followers

#### List all your leaders (people you follow who don't follow you back)
    t leaders -l --sort=followers

#### Mute everyone you follow
    t followings | xargs t mute

#### Unfollow everyone you follow who doesn't follow you back
    t leaders | xargs t unfollow

#### Unfollow 10 people who haven't tweeted in the longest time
    t followings -l --sort=tweeted | head -10 | awk '{print $1}' | xargs t unfollow -i

#### Twitter roulette: randomly follow someone who follows you (who you don't already follow)
    t groupies | shuf | head -1 | xargs t follow

#### Favorite the last 10 tweets that mention you
    t mentions -n 10 -l | awk '{print $1}' | xargs t favorite

#### Output the last 200 tweets in your timeline to a CSV file
    t timeline -n 200 --csv > timeline.csv

#### Start streaming your timeline (Control-C to stop)
    t stream timeline

#### Count the number of official Twitter engineering accounts
    t list members twitter/engineering | wc -l

#### Search Twitter for the 20 most recent Tweets that match a specified query
    t search all "query"

#### Download the latest Linux kernel via BitTorrent (possibly NSFW, depending on where you work)
    t search all "lang:en filter:links linux torrent" -n 1 | grep -o "http://t.co/[0-9A-Za-z]*" | xargs open

#### Search Tweets you've favorited that match a specified query
    t search favorites "query"

#### Search Tweets mentioning you that match a specified query
    t search mentions "query"

#### Search Tweets you've retweeted that match a specified query
    t search retweets "query"

#### Search Tweets in your home timeline that match a specified query
    t search timeline "query"
**Note**: In Twitter API parlance, your “home timeline” is your “Newsfeed” whereas your “user timeline” are the tweets tweeted (and retweeted) by you.

#### Search Tweets in a specified user’s timeline
    t search timeline @sferik "query"

## Features
* Deep search: Instead of using the Twitter Search API, [which only goes
  back 6-9 days][search], `t search` fetches up to 3,200 tweets via the REST API
  and then checks each one against a regular expression.
* Multi-threaded: Whenever possible, Twitter API requests are made in parallel,
  resulting in faster performance for bulk operations.
* Designed for Unix: Output is designed to be piped to other Unix utilities,
  like grep, comm, cut, awk, bc, wc, and xargs for advanced text processing.
* Generate spreadsheets: Convert the output of any command to CSV format simply
  by adding the `--csv` flag.
* 95% C0 Code Coverage: Well tested, with a 2.5:1 test-to-code ratio.

[search]: https://dev.twitter.com/rest/public/search

## Using T for Backup
[@jphpsf][jphpsf] wrote a [blog post][blog] explaining how to use `t` to backup
your Twitter account.

[jphpsf]: https://github.com/jphpsf
[blog]: http://blog.jphpsf.com/2012/05/07/backing-up-your-twitter-account-with-t/

`t` was also mentioned on [an episode of the Ruby 5 podcast][ruby5].

`t` was also discussed on [an episode of the Ruby Rogues podcast][rubyrogues].

[ruby5]: https://ruby5.codeschool.com/episodes/273-episode-269-may-4th-2012/stories/2400-t-command-line-power-tool-for-twitter

[rubyrogues]: https://devchat.tv/ruby-rogues/127-rr-erik-michaels-ober

If you discuss `t` in a blog post or podcast, [let me know][email] and I'll
link it here.

[email]: mailto:sferik@gmail.com

## Relationship Terminology
There is some ambiguity in the terminology used to describe relationships on
Twitter. For example, some people use the term "friends" to mean everyone you
follow. In `t`, "friends" refers to just the subset of people who follow you
back (i.e., friendship is bidirectional). Here is the full table of terminology
used by `t`:

                               ___________________________________________________
                              |                         |                         |
                              |     YOU FOLLOW THEM     |  YOU DON'T FOLLOW THEM  |
     _________________________|_________________________|_________________________|_________________________
    |                         |                         |                         |                         |
    |     THEY FOLLOW YOU     |         friends         |        groupies         |        followers        |
    |_________________________|_________________________|_________________________|_________________________|
    |                         |                         |
    |  THEY DON'T FOLLOW YOU  |         leaders         |
    |_________________________|_________________________|
                              |                         |
                              |       followings        |
                              |_________________________|

## Screenshots
![Timeline](https://github.com/sferik/t/raw/master/screenshots/timeline.png)
![List](https://github.com/sferik/t/raw/master/screenshots/list.png)

## Shell completion
If you're running Zsh or Bash, you can source one of the [bundled completion
files][completion] to get shell completion for `t` commands, subcommands, and
flags.

Don't run Zsh or Bash? Why not [contribute][] completion support for your
favorite shell?

[completion]: https://github.com/sferik/t/tree/master/etc
[contribute]: https://github.com/sferik/t/blob/master/CONTRIBUTING.md

## History
The [twitter gem][gem] previously contained a command-line interface, up until
version 0.5.0, when it was [removed][]. This project is offered as a successor
to that effort, however it is a clean room implementation that contains none of
the original code.

[gem]: https://rubygems.org/gems/twitter
[removed]: https://github.com/jnunemaker/twitter/commit/dd2445e3e2c97f38b28a3f32ea902536b3897adf
![History](https://github.com/sferik/t/raw/master/screenshots/history.png)

## Supported Ruby Versions
This library aims to support and is [tested against][travis] the following Ruby
implementations:

* Ruby 2.4
* Ruby 2.5
* Ruby 2.6
* Ruby 2.7

If something doesn't work on one of these Ruby versions, it's a bug.

This library may inadvertently work (or seem to work) on other Ruby
implementations, however support will only be provided for the versions listed
above.

If you would like this library to support another Ruby version, you may
volunteer to be a maintainer. Being a maintainer entails making sure all tests
run and pass on that implementation. When something breaks on your
implementation, you will be responsible for providing patches in a timely
fashion. If critical issues for a particular implementation exist at the time
of a major release, support for that Ruby version may be dropped.

## Troubleshooting
If you are running t on a remote computer you can use the flag --display-uri during authorize process to display the url instead of opening the web browser.

    t authorize --display-uri

## Copyright
Copyright (c) 2011-2016 Erik Michaels-Ober. See [LICENSE][] for details.
Application icon by [@nvk][nvk].

[license]: https://github.com/sferik/t/blob/master/LICENSE.md
[nvk]: http://www.rnvk.org
