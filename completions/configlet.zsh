#compdef configlet

autoload -U is-at-least

(( $+functions[_configlet_commands] )) ||
_configlet_commands() {
  local commands
  commands=(
    # subcommands with no options
    "generate:Generate concept exercise introductions" \
    "lint:Check the track configuration for correctness" \
    # subcommands with options
    "completion:Output a completion script for a given shell" \
    "fmt:Format the exercise '.meta/config.json' files" \
    "info:Print track information" \
    "sync:Check or update Practice Exercise docs, metadata, and tests" \
    "uuid:Output a version 4 UUID" \
  )
  _describe -t commands 'configlet commands' commands "$@"
}

_configlet() {
  typeset -a _arguments_options

  if is-at-least 5.2; then
    _arguments_options=(-s -S -C)
  else
    _arguments_options=(-s -C)
  fi

  local line
  local curcontext="$curcontext"

  _configlet_global_opts=(
    {-h,--help}'[Show help]'
    '--version[Show version information]'
    '(-t --track-dir)'{-t+,--track-dir=}'[Select a track directory]:'
    {-v,--verbosity}'[Verbosity level]: :(quiet normal detailed)'
  )

  _arguments "${_arguments_options[@]}" \
      "$_configlet_global_opts[@]" \
      ":: :_configlet_commands" \
      "*::: :->configlet"

  words=($line[1] "${words[@]}")
  (( CURRENT += 1 ))
  curcontext="${curcontext%:*:*}:configlet-command-$line[1]:"

  case $line[1] in
    # subcommands with no options
    (generate)
      _arguments "${_arguments_options[@]}" \
          "$_configlet_global_opts[@]" \
      ;;
    (lint)
      _arguments "${_arguments_options[@]}" \
         "$_configlet_global_opts[@]" \
      ;;
    # subcommands with options
    (completion)
      _arguments "${_arguments_options[@]}" \
          "$_configlet_global_opts[@]" \
          {-s,--shell}'[Select the shell type]: :(bash fish zsh)' \
      ;;
    (fmt)
      _arguments "${_arguments_options[@]}" \
          "$_configlet_global_opts[@]" \
          '(-e --exercise)'{-e+,--exercise=}'[exercise slug]:' \
          {-u,--update}'[Write changes]' \
          {-y,--yes}'[Auto-confirm update]' \
      ;;
    (info)
      _arguments "${_arguments_options[@]}" \
          "$_configlet_global_opts[@]" \
          {-o,--offline}'[Do not update prob-specs cache]' \
      ;;
    (sync)
      _arguments "${_arguments_options[@]}" \
          "$_configlet_global_opts[@]" \
          '(-e --exercise)'{-e+,--exercise=}'[exercise slug]:' \
          {-o,--offline}'[Do not update prob-specs cache]' \
          {-u,--update}'[Write changes]' \
          {-y,--yes}'[Auto-confirm update]' \
          '--docs[Sync docs only]' \
          '--filepaths[Populate .meta/config.json "files" entry]' \
          '--metadata[Sync metadata only]' \
          '--tests[For auto-confirming]: :(choose include exclude)' \
      ;;
    (uuid)
      _arguments "${_arguments_options[@]}" \
          "$_configlet_global_opts[@]" \
          '(-n --num)'{-n+,--num=}'[How many UUIDs]:' \
      ;;
  esac
}

_configlet "$@"
