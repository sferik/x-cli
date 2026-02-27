#compdef t

# Completion for Zsh. Source from somewhere in your $fpath.

_t (){
  local -a t_general_options

  t_general_options=("(-H --host)"{-H,--host=}"[Twitter API server]:URL:_urls"
    "(-C --color)"{-C,--color}"[Control how color is used in output]"
    "(-U --no-ssl)"{-U,--no-ssl}"[Disable SSL]"
    "(-P --profile)"{-P,--profile=}"[Path to RC file]:file:_files"
    $nul_arg
  )


  if (( CURRENT > 2 )); then
    (( CURRENT-- ))
    shift words
    _call_function 1 _t_${words[1]}
  else
    _values "t command" \
      "accounts[List accounts]" \
      "authorize[Allows an application to request user authorization]" \
      "block[Block users.]" \
      "direct_messages[Returns the 20 most recent Direct Messages sent to you.]" \
      "direct_messages_sent[Returns the 20 most recent Direct Messages you\'ve sent.]" \
      "dm[Sends that person a Direct Message.]" \
      "does_contain[Find out whether a list contains a user.]" \
      "does_follow[Find out whether one user follows another.]" \
      "favorite[Marks Tweets as favorites.]" \
      "favorites[Returns the 20 most recent Tweets you favorited.]" \
      "follow[Allows you to start following users.]" \
      "followings[Returns a list of the people you follow on Twitter.]" \
      "followings_following[Displays your friends who follow the specified user.]" \
      "followers[Returns a list of the people who follow you on Twitter.]" \
      "friends[Returns the list of people who you follow and follow you back.]" \
      "groupies[Returns the list of people who follow you but you don\'t follow back.]" \
      "intersection[Displays the intersection of users followed by the specified users.]" \
      "leaders[Returns the list of people who you follow but don\'t follow you back.]" \
      "lists[Returns the lists created by a user.]" \
      "matrix[Unfortunately, no one can be told what the Matrix is. You have to see it for yourself.]" \
      "mentions[Returns the 20 most recent Tweets mentioning you.]" \
      "mute[Mute users.]" \
      "muted[Returns a list of the people you have muted on Twitter.]" \
      "open[Opens that user\'s profile in a web browser.]" \
      "reach[Shows the maximum number of people who may have seen the specified tweet in their timeline.]" \
      "reply[Post your Tweet as a reply directed at another person.]" \
      "report_spam[Report users for spam.]" \
      "retweet[Sends Tweets to your followers.]" \
      "retweets[Returns the 20 most recent Retweets by a user.]" \
      "retweets_of_me[Returns the 20 most recent Tweets of the authenticated user that have been retweeted by others.]" \
      "ruler[Prints a 280-character ruler]" \
      "status[Retrieves detailed information about a Tweet.]" \
      "timeline[Returns the 20 most recent Tweets posted by a user.]" \
      "trends[Returns the top 50 trending topics.]" \
      "trend_locations[Returns the locations for which Twitter has trending topic information.]" \
      "unfollow[Allows you to stop following users.]" \
      "update[Post a Tweet.]" \
      "users[Returns a list of users you specify.]" \
      "version[Show version.]" \
      "whois[Retrieves profile information for the user.]" \
      "whoami[Retrieves profile information for the authenticated user.]" \
      "delete[Delete Tweets, Direct Messages, etc.]" \
      "list[Do various things with lists.]" \
      "search[Search through Tweets.]" \
      "set[Change various account settings.]" \
      "stream[Commands for streaming Tweets.]" \

  fi
}

_t_accounts() {
  _arguments \
    $t_general_options && ret=0
}

_t_authorize() {
  _arguments \
    "(-d --display-uri)"{-d,--display-uri}"[Display the authorization URL instead of attempting to open it.]" \
    $t_general_options && ret=0
}

_t_block() {
  _arguments \
    "(-i --id)"{-i,--id}"[Specify input as Twitter user IDs instead of screen names.]" \
    $t_general_options && ret=0
}

_t_direct_messages() {
  _arguments \
    "(-c --csv)"{-c,--csv}"[Output in CSV format.]" \
    "(-d --decode_uris)"{-d,--decode_uris}"[Decodes t.co URLs into their original form.]" \
    "(-l --long)"{-l,--long}"[Output in long format.]" \
    "(-n --number)"{-n,--number}"[Limit the number of results.]" \
    "(-a --relative_dates)"{-a,--relative_dates}"[Show relative dates.]" \
    "(-r --reverse)"{-r,--reverse}"[Reverse the order of the sort.]" \
    $t_general_options && ret=0
}

_t_direct_messages_sent() {
  _arguments \
    "(-c --csv)"{-c,--csv}"[Output in CSV format.]" \
    "(-d --decode_uris)"{-d,--decode_uris}"[Decodes t.co URLs into their original form.]" \
    "(-l --long)"{-l,--long}"[Output in long format.]" \
    "(-n --number)"{-n,--number}"[Limit the number of results.]" \
    "(-a --relative_dates)"{-a,--relative_dates}"[Show relative dates.]" \
    "(-r --reverse)"{-r,--reverse}"[Reverse the order of the sort.]" \
    $t_general_options && ret=0
}

_t_dm() {
  _arguments \
    "(-i --id)"{-i,--id}"[Specify user via ID instead of screen name.]" \
    $t_general_options && ret=0
}

_t_does_contain() {
  _arguments \
    "(-i --id)"{-i,--id}"[Specify user via ID instead of screen name.]" \
    $t_general_options && ret=0
}

_t_does_follow() {
  _arguments \
    "(-i --id)"{-i,--id}"[Specify user via ID instead of screen name.]" \
    $t_general_options && ret=0
}

_t_favorite() {
  _arguments \
    $t_general_options && ret=0
}

_t_favorites() {
  _arguments \
    "(-c --csv)"{-c,--csv}"[Output in CSV format.]" \
    "(-d --decode_uris)"{-d,--decode_uris}"[Decodes t.co URLs into their original form.]" \
    "(-i --id)"{-i,--id}"[Specify user via ID instead of screen name.]" \
    "(-l --long)"{-l,--long}"[Output in long format.]" \
    "(-m --max_id)"{-m,--max_id}"[Returns only the results with an ID less than the specified ID.]" \
    "(-n --number)"{-n,--number}"[Limit the number of results.]" \
    "(-a --relative_dates)"{-a,--relative_dates}"[Show relative dates.]" \
    "(-r --reverse)"{-r,--reverse}"[Reverse the order of the sort.]" \
    "(-s --since_id)"{-s,--since_id}"[Returns only the results with an ID greater than the specified ID.]" \
    $t_general_options && ret=0
}

_t_follow() {
  _arguments \
    "(-i --id)"{-i,--id}"[Specify input as Twitter user IDs instead of screen names.]" \
    $t_general_options && ret=0
}

_t_followings() {
  _arguments \
    "(-c --csv)"{-c,--csv}"[Output in CSV format.]" \
    "(-i --id)"{-i,--id}"[Specify user via ID instead of screen name.]" \
    "(-l --long)"{-l,--long}"[Output in long format.]" \
    "(-a --relative_dates)"{-a,--relative_dates}"[Show relative dates.]" \
    "(-r --reverse)"{-r,--reverse}"[Reverse the order of the sort.]" \
    "(-s --sort)"{-s,--sort}"[Specify the order of the results.]" \
    "(-u --unsorted)"{-u,--unsorted}"[Output is not sorted.]" \
    $t_general_options && ret=0
}

_t_followings_following() {
  _arguments \
    "(-c --csv)"{-c,--csv}"[Output in CSV format.]" \
    "(-i --id)"{-i,--id}"[Specify input as Twitter user IDs instead of screen names.]" \
    "(-l --long)"{-l,--long}"[Output in long format.]" \
    "(-a --relative_dates)"{-a,--relative_dates}"[Show relative dates.]" \
    "(-r --reverse)"{-r,--reverse}"[Reverse the order of the sort.]" \
    "(-s --sort)"{-s,--sort}"[Specify the order of the results.]" \
    "(-u --unsorted)"{-u,--unsorted}"[Output is not sorted.]" \
    $t_general_options && ret=0
}

_t_followers() {
  _arguments \
    "(-c --csv)"{-c,--csv}"[Output in CSV format.]" \
    "(-i --id)"{-i,--id}"[Specify user via ID instead of screen name.]" \
    "(-l --long)"{-l,--long}"[Output in long format.]" \
    "(-a --relative_dates)"{-a,--relative_dates}"[Show relative dates.]" \
    "(-r --reverse)"{-r,--reverse}"[Reverse the order of the sort.]" \
    "(-s --sort)"{-s,--sort}"[Specify the order of the results.]" \
    "(-u --unsorted)"{-u,--unsorted}"[Output is not sorted.]" \
    $t_general_options && ret=0
}

_t_friends() {
  _arguments \
    "(-c --csv)"{-c,--csv}"[Output in CSV format.]" \
    "(-i --id)"{-i,--id}"[Specify user via ID instead of screen name.]" \
    "(-l --long)"{-l,--long}"[Output in long format.]" \
    "(-a --relative_dates)"{-a,--relative_dates}"[Show relative dates.]" \
    "(-r --reverse)"{-r,--reverse}"[Reverse the order of the sort.]" \
    "(-s --sort)"{-s,--sort}"[Specify the order of the results.]" \
    "(-u --unsorted)"{-u,--unsorted}"[Output is not sorted.]" \
    $t_general_options && ret=0
}

_t_groupies() {
  _arguments \
    "(-c --csv)"{-c,--csv}"[Output in CSV format.]" \
    "(-i --id)"{-i,--id}"[Specify user via ID instead of screen name.]" \
    "(-l --long)"{-l,--long}"[Output in long format.]" \
    "(-a --relative_dates)"{-a,--relative_dates}"[Show relative dates.]" \
    "(-r --reverse)"{-r,--reverse}"[Reverse the order of the sort.]" \
    "(-s --sort)"{-s,--sort}"[Specify the order of the results.]" \
    "(-u --unsorted)"{-u,--unsorted}"[Output is not sorted.]" \
    $t_general_options && ret=0
}

_t_intersection() {
  _arguments \
    "(-c --csv)"{-c,--csv}"[Output in CSV format.]" \
    "(-i --id)"{-i,--id}"[Specify input as Twitter user IDs instead of screen names.]" \
    "(-l --long)"{-l,--long}"[Output in long format.]" \
    "(-a --relative_dates)"{-a,--relative_dates}"[Show relative dates.]" \
    "(-r --reverse)"{-r,--reverse}"[Reverse the order of the sort.]" \
    "(-s --sort)"{-s,--sort}"[Specify the order of the results.]" \
    "(-t --type)"{-t,--type}"[Specify the type of intersection.]" \
    "(-u --unsorted)"{-u,--unsorted}"[Output is not sorted.]" \
    $t_general_options && ret=0
}

_t_leaders() {
  _arguments \
    "(-c --csv)"{-c,--csv}"[Output in CSV format.]" \
    "(-i --id)"{-i,--id}"[Specify user via ID instead of screen name.]" \
    "(-l --long)"{-l,--long}"[Output in long format.]" \
    "(-a --relative_dates)"{-a,--relative_dates}"[Show relative dates.]" \
    "(-r --reverse)"{-r,--reverse}"[Reverse the order of the sort.]" \
    "(-s --sort)"{-s,--sort}"[Specify the order of the results.]" \
    "(-u --unsorted)"{-u,--unsorted}"[Output is not sorted.]" \
    $t_general_options && ret=0
}

_t_lists() {
  _arguments \
    "(-c --csv)"{-c,--csv}"[Output in CSV format.]" \
    "(-i --id)"{-i,--id}"[Specify user via ID instead of screen name.]" \
    "(-l --long)"{-l,--long}"[Output in long format.]" \
    "(-a --relative_dates)"{-a,--relative_dates}"[Show relative dates.]" \
    "(-r --reverse)"{-r,--reverse}"[Reverse the order of the sort.]" \
    "(-s --sort)"{-s,--sort}"[Specify the order of the results.]" \
    "(-u --unsorted)"{-u,--unsorted}"[Output is not sorted.]" \
    $t_general_options && ret=0
}

_t_matrix() {
  _arguments \
    $t_general_options && ret=0
}

_t_mentions() {
  _arguments \
    "(-c --csv)"{-c,--csv}"[Output in CSV format.]" \
    "(-d --decode_uris)"{-d,--decode_uris}"[Decodes t.co URLs into their original form.]" \
    "(-l --long)"{-l,--long}"[Output in long format.]" \
    "(-n --number)"{-n,--number}"[Limit the number of results.]" \
    "(-a --relative_dates)"{-a,--relative_dates}"[Show relative dates.]" \
    "(-r --reverse)"{-r,--reverse}"[Reverse the order of the sort.]" \
    $t_general_options && ret=0
}

_t_mute() {
  _arguments \
    "(-i --id)"{-i,--id}"[Specify input as Twitter user IDs instead of screen names.]" \
    $t_general_options && ret=0
}

_t_muted() {
  _arguments \
    "(-c --csv)"{-c,--csv}"[Output in CSV format.]" \
    "(-l --long)"{-l,--long}"[Output in long format.]" \
    "(-a --relative_dates)"{-a,--relative_dates}"[Show relative dates.]" \
    "(-r --reverse)"{-r,--reverse}"[Reverse the order of the sort.]" \
    "(-s --sort)"{-s,--sort}"[Specify the order of the results.]" \
    "(-u --unsorted)"{-u,--unsorted}"[Output is not sorted.]" \
    $t_general_options && ret=0
}

_t_open() {
  _arguments \
    "(-d --display-uri)"{-d,--display-uri}"[Display the requested URL instead of attempting to open it.]" \
    "(-i --id)"{-i,--id}"[Specify user via ID instead of screen name.]" \
    "(-s --status)"{-s,--status}"[Specify input as a Twitter status ID instead of a screen name.]" \
    $t_general_options && ret=0
}

_t_reach() {
  _arguments \
    $t_general_options && ret=0
}

_t_reply() {
  _arguments \
    "(-a --all)"{-a,--all}"[Reply to all users mentioned in the Tweet.]" \
    "(-l --location)"{-l,--location}"[Add location information. If the optional \'latitude,longitude\' parameter is not supplied, looks up location by IP address.]" \
    "(-f --file)"{-f,--file}"[The path to an image to attach to your tweet.]" \
    $t_general_options && ret=0
}

_t_report_spam() {
  _arguments \
    "(-i --id)"{-i,--id}"[Specify input as Twitter user IDs instead of screen names.]" \
    $t_general_options && ret=0
}

_t_retweet() {
  _arguments \
    $t_general_options && ret=0
}

_t_retweets() {
  _arguments \
    "(-c --csv)"{-c,--csv}"[Output in CSV format.]" \
    "(-d --decode_uris)"{-d,--decode_uris}"[Decodes t.co URLs into their original form.]" \
    "(-i --id)"{-i,--id}"[Specify user via ID instead of screen name.]" \
    "(-l --long)"{-l,--long}"[Output in long format.]" \
    "(-n --number)"{-n,--number}"[Limit the number of results.]" \
    "(-a --relative_dates)"{-a,--relative_dates}"[Show relative dates.]" \
    "(-r --reverse)"{-r,--reverse}"[Reverse the order of the sort.]" \
    $t_general_options && ret=0
}

_t_retweets_of_me() {
  _arguments \
    "(-c --csv)"{-c,--csv}"[Output in CSV format.]" \
    "(-d --decode_uris)"{-d,--decode_uris}"[Decodes t.co URLs into their original form.]" \
    "(-l --long)"{-l,--long}"[Output in long format.]" \
    "(-n --number)"{-n,--number}"[Limit the number of results.]" \
    "(-a --relative_dates)"{-a,--relative_dates}"[Show relative dates.]" \
    "(-r --reverse)"{-r,--reverse}"[Reverse the order of the sort.]" \
    $t_general_options && ret=0
}

_t_ruler() {
  _arguments \
    "(-i --indent)"{-i,--indent}"[The number of spaces to print before the ruler.]" \
    $t_general_options && ret=0
}

_t_status() {
  _arguments \
    "(-c --csv)"{-c,--csv}"[Output in CSV format.]" \
    "(-d --decode_uris)"{-d,--decode_uris}"[Decodes t.co URLs into their original form.]" \
    "(-l --long)"{-l,--long}"[Output in long format.]" \
    "(-a --relative_dates)"{-a,--relative_dates}"[Show relative dates.]" \
    $t_general_options && ret=0
}

_t_timeline() {
  _arguments \
    "(-c --csv)"{-c,--csv}"[Output in CSV format.]" \
    "(-d --decode_uris)"{-d,--decode_uris}"[Decodes t.co URLs into their original form.]" \
    "(-e --exclude)"{-e,--exclude}"[Exclude certain types of Tweets from the results.]" \
    "(-i --id)"{-i,--id}"[Specify user via ID instead of screen name.]" \
    "(-l --long)"{-l,--long}"[Output in long format.]" \
    "(-m --max_id)"{-m,--max_id}"[Returns only the results with an ID less than the specified ID.]" \
    "(-n --number)"{-n,--number}"[Limit the number of results.]" \
    "(-a --relative_dates)"{-a,--relative_dates}"[Show relative dates.]" \
    "(-r --reverse)"{-r,--reverse}"[Reverse the order of the sort.]" \
    "(-s --since_id)"{-s,--since_id}"[Returns only the results with an ID greater than the specified ID.]" \
    $t_general_options && ret=0
}

_t_trends() {
  _arguments \
    "(-x --exclude-hashtags)"{-x,--exclude-hashtags}"[Remove all hashtags from the trends list.]" \
    $t_general_options && ret=0
}

_t_trend_locations() {
  _arguments \
    "(-c --csv)"{-c,--csv}"[Output in CSV format.]" \
    "(-l --long)"{-l,--long}"[Output in long format.]" \
    "(-a --relative_dates)"{-a,--relative_dates}"[Show relative dates.]" \
    "(-r --reverse)"{-r,--reverse}"[Reverse the order of the sort.]" \
    "(-s --sort)"{-s,--sort}"[Specify the order of the results.]" \
    "(-u --unsorted)"{-u,--unsorted}"[Output is not sorted.]" \
    $t_general_options && ret=0
}

_t_unfollow() {
  _arguments \
    "(-i --id)"{-i,--id}"[Specify input as Twitter user IDs instead of screen names.]" \
    $t_general_options && ret=0
}

_t_update() {
  _arguments \
    "(-l --location)"{-l,--location}"[Add location information. If the optional \'latitude,longitude\' parameter is not supplied, looks up location by IP address.]" \
    "(-f --file)"{-f,--file}"[The path to an image to attach to your tweet.]" \
    $t_general_options && ret=0
}

_t_users() {
  _arguments \
    "(-c --csv)"{-c,--csv}"[Output in CSV format.]" \
    "(-i --id)"{-i,--id}"[Specify input as Twitter user IDs instead of screen names.]" \
    "(-l --long)"{-l,--long}"[Output in long format.]" \
    "(-a --relative_dates)"{-a,--relative_dates}"[Show relative dates.]" \
    "(-r --reverse)"{-r,--reverse}"[Reverse the order of the sort.]" \
    "(-s --sort)"{-s,--sort}"[Specify the order of the results.]" \
    "(-u --unsorted)"{-u,--unsorted}"[Output is not sorted.]" \
    $t_general_options && ret=0
}

_t_version() {
  _arguments \
    $t_general_options && ret=0
}

_t_whois() {
  _arguments \
    "(-c --csv)"{-c,--csv}"[Output in CSV format.]" \
    "(-d --decode_uris)"{-d,--decode_uris}"[Decodes t.co URLs into their original form.]" \
    "(-i --id)"{-i,--id}"[Specify user via ID instead of screen name.]" \
    "(-l --long)"{-l,--long}"[Output in long format.]" \
    "(-a --relative_dates)"{-a,--relative_dates}"[Show relative dates.]" \
    $t_general_options && ret=0
}

_t_whoami() {
  _arguments \
    "(-c --csv)"{-c,--csv}"[Output in CSV format.]" \
    "(-d --decode_uris)"{-d,--decode_uris}"[Decodes t.co URLs into their original form.]" \
    "(-l --long)"{-l,--long}"[Output in long format.]" \
    "(-a --relative_dates)"{-a,--relative_dates}"[Show relative dates.]" \
    $t_general_options && ret=0
}


__t_delete_arguments() {
  _args=(block
    dm
    favorite
    list
    mute
    account
    status
    help
  )
  compadd "$@" -k _args
}

__t_list_arguments() {
  _args=(add
    create
    information
    members
    remove
    timeline
    help
  )
  compadd "$@" -k _args
}

__t_search_arguments() {
  _args=(all
    favorites
    list
    mentions
    retweets
    timeline
    users
    help
  )
  compadd "$@" -k _args
}

__t_set_arguments() {
  _args=(active
    bio
    language
    location
    name
    profile_background_image
    profile_image
    website
    help
  )
  compadd "$@" -k _args
}

__t_stream_arguments() {
  _args=(all
    list
    matrix
    search
    timeline
    users
    help
  )
  compadd "$@" -k _args
}


_t_delete() {
  _arguments \
    ":argument:__t_delete_arguments" \
    $t_general_options && ret=0
}

_t_list() {
  _arguments \
    ":argument:__t_list_arguments" \
    $t_general_options && ret=0
}

_t_search() {
  _arguments \
    ":argument:__t_search_arguments" \
    $t_general_options && ret=0
}

_t_set() {
  _arguments \
    ":argument:__t_set_arguments" \
    $t_general_options && ret=0
}

_t_stream() {
  _arguments \
    ":argument:__t_stream_arguments" \
    $t_general_options && ret=0
}
