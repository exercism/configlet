# completions for the configlet command, bash flavour

# remove any prior completions
complete -r bin/configlet configlet 2> /dev/null
# and install this one
complete -F _configlet_completion_ configlet

# @(pattern1|pattern2|...) is bash extended pattern matching meaning
# "one of pattern1 or pattern2 or ..."
# ref: https://www.gnu.org/software/bash/manual/bash.html#Pattern-Matching

_configlet_completion_() {
  local global_opts='-h --help --version -t --track-dir -v --verbosity'
  local cur=${COMP_WORDS[COMP_CWORD]}
  local prev=${COMP_WORDS[COMP_CWORD - 1]}

  # Check for global options that take a value
  if _configlet_complete_global_option_; then
    return
  fi

  local i
  for ((i = 1; i < COMP_CWORD; i++)); do
    if [[ ${COMP_WORDS[i]} == @(completion|create|lint|generate|info|uuid|fmt|sync) ]]; then
      "_configlet_complete_${COMP_WORDS[i]}_"
      return
    fi
  done

  _configlet_complete_options_ "completion create fmt generate info lint sync uuid $global_opts"
}

_configlet_complete_global_option_() {
  case $prev in
    '-v' | '--verbosity')
      _configlet_complete_options_ "quiet normal detailed"
      return 0
      ;;
    '-t' | '--track-dir')
      # Complete a directory based on what the user's typed so far
      mapfile -t COMPREPLY < <(compgen -A directory -- "$cur")
      return 0
      ;;
  esac
  return 1
}

_configlet_complete_completion_() {
  case $prev in
    '-s' | '--shell')
      _configlet_complete_options_ "bash fish zsh"
      ;;
    *)
      _configlet_complete_options_ "-s --shell $global_opts"
      ;;
  esac
}

_configlet_complete_lint_() {
  _configlet_complete_options_ "$global_opts"
}

_configlet_complete_generate_() {
  _configlet_complete_options_ "$global_opts"
}

_configlet_complete_info_() {
  _configlet_complete_options_ "-o --offline $global_opts"
}

_configlet_complete_uuid_() {
  case $prev in
    '-n' | '--num')
      return 0 # Don't suggest a global option if -n has no argument.
      ;;
    *)
      _configlet_complete_options_ "-n --num $global_opts"
      ;;
  esac
}

_configlet_complete_create_() {
  case $prev in
    '-e' | '--exercise')
      _configlet_complete_slugs_ "practice" "concept"
      ;;
    *)
      _configlet_complete_options_ "--approach --article --concept-exercise -e --exercise --practice-exercise $global_opts"
      ;;
  esac
}

_configlet_complete_fmt_() {
  case $prev in
    '-e' | '--exercise')
      _configlet_complete_slugs_ "practice" "concept"
      ;;
    *)
      _configlet_complete_options_ "-e --exercise -u --update -y --yes $global_opts"
      ;;
  esac
}

_configlet_complete_sync_() {
  case $prev in
    '--tests')
      _configlet_complete_options_ "choose include exclude"
      ;;
    '-e' | '--exercise')
      _configlet_complete_slugs_ "practice"
      ;;
    *)
      local options=(
        -e --exercise
        -o --offline
        -u --update
        -y --yes
           --docs
           --filepaths
           --metadata
           --tests
      )
      _configlet_complete_options_ "${options[*]} $global_opts"
      ;;
  esac
}

# Note that configlet expects to be called from the track's root dir.
_configlet_complete_slugs_() {
  local subdir
  mapfile -t COMPREPLY < <(
    for subdir in "$@"; do
      if [[ -d "./exercises/$subdir" ]]; then
        ( cd "./exercises/$subdir" && compgen -A directory -- "$cur" )
      fi
    done
  )
}

_configlet_complete_options_() {
  local choices=$1
  mapfile -t COMPREPLY < <(compgen -o nosort -W "$choices" -- "$cur")
}
