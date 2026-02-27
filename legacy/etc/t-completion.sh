# Completion for Bash. Copy it in /etc/bash_completion.d/ or source it
      # somewhere in your ~/.bashrc

      _t() {

        local cur prev completions

        COMPREPLY=()
        cur=${COMP_WORDS[COMP_CWORD]}
        topcmd=${COMP_WORDS[1]}
        prev=${COMP_WORDS[COMP_CWORD-1]}

        COMMANDS='accounts authorize block direct_messages direct_messages_sent dm does_contain does_follow favorite favorites follow followings followings_following followers friends groupies intersection leaders lists matrix mentions mute muted open reach reply report_spam retweet retweets retweets_of_me ruler status timeline trends trend_locations unfollow update users version whois whoami delete list search set stream'

        case "$topcmd" in
          accounts)
              case "$prev" in
              
              -C|--color) completions='auto never' ;;

              *) completions='-H --host -C --color -P --profile' ;;
              esac;;

authorize)
              case "$prev" in
              
              -C|--color) completions='auto never' ;;

              *) completions='--display-uri -d -H --host -C --color -P --profile' ;;
              esac;;

block)
              case "$prev" in
              
              -C|--color) completions='auto never' ;;

              *) completions='--id -i -H --host -C --color -P --profile' ;;
              esac;;

direct_messages)
              case "$prev" in
              
              -C|--color) completions='auto never' ;;

              *) completions='--csv -c --decode_uris -d --long -l --number -n --relative_dates -a --reverse -r -H --host -C --color -P --profile' ;;
              esac;;

direct_messages_sent)
              case "$prev" in
              
              -C|--color) completions='auto never' ;;

              *) completions='--csv -c --decode_uris -d --long -l --number -n --relative_dates -a --reverse -r -H --host -C --color -P --profile' ;;
              esac;;

dm)
              case "$prev" in
              
              -C|--color) completions='auto never' ;;

              *) completions='--id -i -H --host -C --color -P --profile' ;;
              esac;;

does_contain)
              case "$prev" in
              
              -C|--color) completions='auto never' ;;

              *) completions='--id -i -H --host -C --color -P --profile' ;;
              esac;;

does_follow)
              case "$prev" in
              
              -C|--color) completions='auto never' ;;

              *) completions='--id -i -H --host -C --color -P --profile' ;;
              esac;;

favorite)
              case "$prev" in
              
              -C|--color) completions='auto never' ;;

              *) completions='-H --host -C --color -P --profile' ;;
              esac;;

favorites)
              case "$prev" in
              
              -C|--color) completions='auto never' ;;

              *) completions='--csv -c --decode_uris -d --id -i --long -l --max_id -m --number -n --relative_dates -a --reverse -r --since_id -s -H --host -C --color -P --profile' ;;
              esac;;

follow)
              case "$prev" in
              
              -C|--color) completions='auto never' ;;

              *) completions='--id -i -H --host -C --color -P --profile' ;;
              esac;;

followings)
              case "$prev" in
              --sort|-s)
               completions='favorites followers friends listed screen_name since tweets tweeted' ;;
              -C|--color) completions='auto never' ;;

              *) completions='--csv -c --id -i --long -l --relative_dates -a --reverse -r --sort -s --unsorted -u -H --host -C --color -P --profile' ;;
              esac;;

followings_following)
              case "$prev" in
              --sort|-s)
               completions='favorites followers friends listed screen_name since tweets tweeted' ;;
              -C|--color) completions='auto never' ;;

              *) completions='--csv -c --id -i --long -l --relative_dates -a --reverse -r --sort -s --unsorted -u -H --host -C --color -P --profile' ;;
              esac;;

followers)
              case "$prev" in
              --sort|-s)
               completions='favorites followers friends listed screen_name since tweets tweeted' ;;
              -C|--color) completions='auto never' ;;

              *) completions='--csv -c --id -i --long -l --relative_dates -a --reverse -r --sort -s --unsorted -u -H --host -C --color -P --profile' ;;
              esac;;

friends)
              case "$prev" in
              --sort|-s)
               completions='favorites followers friends listed screen_name since tweets tweeted' ;;
              -C|--color) completions='auto never' ;;

              *) completions='--csv -c --id -i --long -l --relative_dates -a --reverse -r --sort -s --unsorted -u -H --host -C --color -P --profile' ;;
              esac;;

groupies)
              case "$prev" in
              --sort|-s)
               completions='favorites followers friends listed screen_name since tweets tweeted' ;;
              -C|--color) completions='auto never' ;;

              *) completions='--csv -c --id -i --long -l --relative_dates -a --reverse -r --sort -s --unsorted -u -H --host -C --color -P --profile' ;;
              esac;;

intersection)
              case "$prev" in
              --sort|-s)
               completions='favorites followers friends listed screen_name since tweets tweeted' ;;
--type|-t)
               completions='followers followings' ;;
              -C|--color) completions='auto never' ;;

              *) completions='--csv -c --id -i --long -l --relative_dates -a --reverse -r --sort -s --type -t --unsorted -u -H --host -C --color -P --profile' ;;
              esac;;

leaders)
              case "$prev" in
              --sort|-s)
               completions='favorites followers friends listed screen_name since tweets tweeted' ;;
              -C|--color) completions='auto never' ;;

              *) completions='--csv -c --id -i --long -l --relative_dates -a --reverse -r --sort -s --unsorted -u -H --host -C --color -P --profile' ;;
              esac;;

lists)
              case "$prev" in
              --sort|-s)
               completions='members mode since slug subscribers' ;;
              -C|--color) completions='auto never' ;;

              *) completions='--csv -c --id -i --long -l --relative_dates -a --reverse -r --sort -s --unsorted -u -H --host -C --color -P --profile' ;;
              esac;;

matrix)
              case "$prev" in
              
              -C|--color) completions='auto never' ;;

              *) completions='-H --host -C --color -P --profile' ;;
              esac;;

mentions)
              case "$prev" in
              
              -C|--color) completions='auto never' ;;

              *) completions='--csv -c --decode_uris -d --long -l --number -n --relative_dates -a --reverse -r -H --host -C --color -P --profile' ;;
              esac;;

mute)
              case "$prev" in
              
              -C|--color) completions='auto never' ;;

              *) completions='--id -i -H --host -C --color -P --profile' ;;
              esac;;

muted)
              case "$prev" in
              --sort|-s)
               completions='favorites followers friends listed screen_name since tweets tweeted' ;;
              -C|--color) completions='auto never' ;;

              *) completions='--csv -c --long -l --relative_dates -a --reverse -r --sort -s --unsorted -u -H --host -C --color -P --profile' ;;
              esac;;

open)
              case "$prev" in
              
              -C|--color) completions='auto never' ;;

              *) completions='--display-uri -d --id -i --status -s -H --host -C --color -P --profile' ;;
              esac;;

reach)
              case "$prev" in
              
              -C|--color) completions='auto never' ;;

              *) completions='-H --host -C --color -P --profile' ;;
              esac;;

reply)
              case "$prev" in
              
              -C|--color) completions='auto never' ;;

              *) completions='--all -a --location -l --file -f -H --host -C --color -P --profile' ;;
              esac;;

report_spam)
              case "$prev" in
              
              -C|--color) completions='auto never' ;;

              *) completions='--id -i -H --host -C --color -P --profile' ;;
              esac;;

retweet)
              case "$prev" in
              
              -C|--color) completions='auto never' ;;

              *) completions='-H --host -C --color -P --profile' ;;
              esac;;

retweets)
              case "$prev" in
              
              -C|--color) completions='auto never' ;;

              *) completions='--csv -c --decode_uris -d --id -i --long -l --number -n --relative_dates -a --reverse -r -H --host -C --color -P --profile' ;;
              esac;;

retweets_of_me)
              case "$prev" in
              
              -C|--color) completions='auto never' ;;

              *) completions='--csv -c --decode_uris -d --long -l --number -n --relative_dates -a --reverse -r -H --host -C --color -P --profile' ;;
              esac;;

ruler)
              case "$prev" in
              
              -C|--color) completions='auto never' ;;

              *) completions='--indent -i -H --host -C --color -P --profile' ;;
              esac;;

status)
              case "$prev" in
              
              -C|--color) completions='auto never' ;;

              *) completions='--csv -c --decode_uris -d --long -l --relative_dates -a -H --host -C --color -P --profile' ;;
              esac;;

timeline)
              case "$prev" in
              --exclude|-e)
               completions='replies retweets' ;;
              -C|--color) completions='auto never' ;;

              *) completions='--csv -c --decode_uris -d --exclude -e --id -i --long -l --max_id -m --number -n --relative_dates -a --reverse -r --since_id -s -H --host -C --color -P --profile' ;;
              esac;;

trends)
              case "$prev" in
              
              -C|--color) completions='auto never' ;;

              *) completions='--exclude-hashtags -x -H --host -C --color -P --profile' ;;
              esac;;

trend_locations)
              case "$prev" in
              --sort|-s)
               completions='country name parent type woeid' ;;
              -C|--color) completions='auto never' ;;

              *) completions='--csv -c --long -l --relative_dates -a --reverse -r --sort -s --unsorted -u -H --host -C --color -P --profile' ;;
              esac;;

unfollow)
              case "$prev" in
              
              -C|--color) completions='auto never' ;;

              *) completions='--id -i -H --host -C --color -P --profile' ;;
              esac;;

update)
              case "$prev" in
              
              -C|--color) completions='auto never' ;;

              *) completions='--location -l --file -f -H --host -C --color -P --profile' ;;
              esac;;

users)
              case "$prev" in
              --sort|-s)
               completions='favorites followers friends listed screen_name since tweets tweeted' ;;
              -C|--color) completions='auto never' ;;

              *) completions='--csv -c --id -i --long -l --relative_dates -a --reverse -r --sort -s --unsorted -u -H --host -C --color -P --profile' ;;
              esac;;

version)
              case "$prev" in
              
              -C|--color) completions='auto never' ;;

              *) completions='-H --host -C --color -P --profile' ;;
              esac;;

whois)
              case "$prev" in
              
              -C|--color) completions='auto never' ;;

              *) completions='--csv -c --decode_uris -d --id -i --long -l --relative_dates -a -H --host -C --color -P --profile' ;;
              esac;;

whoami)
              case "$prev" in
              
              -C|--color) completions='auto never' ;;

              *) completions='--csv -c --decode_uris -d --long -l --relative_dates -a -H --host -C --color -P --profile' ;;
              esac;;

delete)
              case "$prev" in
              delete) completions='block dm favorite list mute account status help';;
              block) completions='-H --host -C --color -P --profile' ;;
dm) completions='-H --host -C --color -P --profile' ;;
favorite) completions='-H --host -C --color -P --profile' ;;
list) completions='-H --host -C --color -P --profile' ;;
mute) completions='-H --host -C --color -P --profile' ;;
account) completions='-H --host -C --color -P --profile' ;;
status) completions='-H --host -C --color -P --profile' ;;
help) completions='-H --host -C --color -P --profile' ;;
              
              -C|--color) completions='auto never' ;;

              *) completions='-H --host -C --color -P --profile';;
              esac;;

list)
              case "$prev" in
              list) completions='add create information members remove timeline help';;
              add) completions='-H --host -C --color -P --profile' ;;
create) completions='-H --host -C --color -P --profile' ;;
information) completions='-H --host -C --color -P --profile' ;;
members) completions='-H --host -C --color -P --profile' ;;
remove) completions='-H --host -C --color -P --profile' ;;
timeline) completions='-H --host -C --color -P --profile' ;;
help) completions='-H --host -C --color -P --profile' ;;
              
              -C|--color) completions='auto never' ;;

              *) completions='-H --host -C --color -P --profile';;
              esac;;

search)
              case "$prev" in
              search) completions='all favorites list mentions retweets timeline users help';;
              all) completions='-H --host -C --color -P --profile' ;;
favorites) completions='-H --host -C --color -P --profile' ;;
list) completions='-H --host -C --color -P --profile' ;;
mentions) completions='-H --host -C --color -P --profile' ;;
retweets) completions='-H --host -C --color -P --profile' ;;
timeline) completions='-H --host -C --color -P --profile' ;;
users) completions='-H --host -C --color -P --profile' ;;
help) completions='-H --host -C --color -P --profile' ;;
              
              -C|--color) completions='auto never' ;;

              *) completions='-H --host -C --color -P --profile';;
              esac;;

set)
              case "$prev" in
              set) completions='active bio language location name profile_background_image profile_image website help';;
              active) completions='-H --host -C --color -P --profile' ;;
bio) completions='-H --host -C --color -P --profile' ;;
language) completions='-H --host -C --color -P --profile' ;;
location) completions='-H --host -C --color -P --profile' ;;
name) completions='-H --host -C --color -P --profile' ;;
profile_background_image) completions='-H --host -C --color -P --profile' ;;
profile_image) completions='-H --host -C --color -P --profile' ;;
website) completions='-H --host -C --color -P --profile' ;;
help) completions='-H --host -C --color -P --profile' ;;
              
              -C|--color) completions='auto never' ;;

              *) completions='-H --host -C --color -P --profile';;
              esac;;

stream)
              case "$prev" in
              stream) completions='all list matrix search timeline users help';;
              all) completions='-H --host -C --color -P --profile' ;;
list) completions='-H --host -C --color -P --profile' ;;
matrix) completions='-H --host -C --color -P --profile' ;;
search) completions='-H --host -C --color -P --profile' ;;
timeline) completions='-H --host -C --color -P --profile' ;;
users) completions='-H --host -C --color -P --profile' ;;
help) completions='-H --host -C --color -P --profile' ;;
              
              -C|--color) completions='auto never' ;;

              *) completions='-H --host -C --color -P --profile';;
              esac;;

          *) completions="$COMMANDS" ;;
        esac

        COMPREPLY=( $( compgen -W "$completions" -- $cur ))
        return 0

      }

      complete -F _t $filenames t
      