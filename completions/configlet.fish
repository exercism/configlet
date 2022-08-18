function __fish_configlet_find_dirs
  find $argv -maxdepth 1 -mindepth 1 -type d -printf '%P\n' | sort
end

# disable file completions everywhere
complete -c configlet -f

# global options
complete -c configlet -s h -l help -d "Show help"
complete -c configlet      -l version -d "Show version info"
complete -c configlet -s t -l track-dir -d "Select a track directory" \
  -xa "(__fish_complete_directories)"
complete -c configlet -s v -l verbosity  -d "Verbose level" \
  -xa "quiet normal detailed"

# subcommands with no options
complete -c configlet -n "__fish_use_subcommand" -a generate -d "Generate concept exercise introductions"
complete -c configlet -n "__fish_use_subcommand" -a lint -d "Check the track configuration for correctness"

# subcommands with options
complete -c configlet -n "__fish_use_subcommand" -a completion -d "Output a completion script for a given shell"
complete -c configlet -n "__fish_use_subcommand" -a fmt -d "Format the exercise '.meta/config.json' files"
complete -c configlet -n "__fish_use_subcommand" -a info -d "Track info"
complete -c configlet -n "__fish_use_subcommand" -a sync -d "Check or update Practice Exercise docs, metadata, and tests"
complete -c configlet -n "__fish_use_subcommand" -a uuid -d "Output a UUID"

# completion subcommand
complete -c configlet -n "__fish_seen_subcommand_from completion" -s s -l shell -d "Shell type" \
  -xa "bash fish zsh"

# fmt subcommand
complete -c configlet -n "__fish_seen_subcommand_from fmt" -s e -l exercise -d "exercise slug" \
  -xa '(__fish_configlet_find_dirs ./exercises/{concept,practice})'
complete -c configlet -n "__fish_seen_subcommand_from fmt" -s u -l update -d "Write changes"
complete -c configlet -n "__fish_seen_subcommand_from fmt" -s y -l yes -d "Auto-confirm update"

# info subcommand
complete -c configlet -n "__fish_seen_subcommand_from info" -s o -l offline -d "Do not update prob-specs cache"

# sync subcommand
complete -c configlet -n "__fish_seen_subcommand_from sync" -s e -l exercise -d "exercise slug" \
  -xa '(__fish_configlet_find_dirs ./exercises/practice)'
complete -c configlet -n "__fish_seen_subcommand_from sync" -s o -l offline -d "Do not update prob-specs cache"
complete -c configlet -n "__fish_seen_subcommand_from sync" -s u -l update -d "Write changes"
complete -c configlet -n "__fish_seen_subcommand_from sync" -s y -l yes -d "Auto-confirm update"
complete -c configlet -n "__fish_seen_subcommand_from sync"      -l docs -d "Sync docs only"
complete -c configlet -n "__fish_seen_subcommand_from sync"      -l filepaths -d 'Populate .meta/config.json "files" entry'
complete -c configlet -n "__fish_seen_subcommand_from sync"      -l metadata -d "Sync metadata only"
complete -c configlet -n "__fish_seen_subcommand_from sync"      -l tests -d "For auto-confirming" \
  -xa "choose include exclude"

# uuid subcommand
complete -c configlet -n "__fish_seen_subcommand_from uuid" -s n -l num -x -d "How many UUIDs"
