#!/bin/bash

# [-e] instruct bash to exit if any command [1] has a non-zero exit status.
# [-o] prevent errors in a pipeline from being masked.
# [-u] fail if found references to any variable which was not previously defined
set -euo pipefail

################################################################################
# GLOBAL VARS
################################################################################
GIT_MVH_VERBOSE=0
GIT_MVH_DRYRUN=0
GIT_MVH_WD="$(pwd)"
GIT_MVH_NAME="git-mvh"
GIT_MVH_REPO=$(basename `git rev-parse --show-toplevel`)
GIT_MVH_FILTER=""
################################################################################
# LOG
################################################################################
git_mvh_loginfo() { printf "\033[94m%s\033[0m %s\n" "[$GIT_MVH_NAME]:" "$*"; }
git_mvh_logerr() { printf "\033[91m%s\033[0m %s\n" "[$GIT_MVH_NAME]:" "$*" >&2; }
git_mvh_logwarn() { printf "\033[33m%s\033[0m %s\n" "[$GIT_MVH_NAME]:" "$*"; }
git_mvh_logok() { printf "\033[32m%s\033[0m %s\n" "[$GIT_MVH_NAME]:" "$*"; }
git_mvh_logline() { printf "%s\n" "$*"; }
git_mvh_logdebug() {
  if [ $GIT_MVH_VERBOSE -gt 0 ]; then
    printf "\033[2m%s\033[0m %s\n" "[$GIT_MVH_NAME]:" "$*";
  fi
}
git_mvh_logmute() { printf "\033[39m%s\033[0m\n" "$*"; }
git_mvh_logbold() { printf "\033[1m%s\033[0m\n" "$*"; }
git_mvh_helpcmd() { printf "\033[1m  %-15s\033[0m %s\n" "$1" "$2"; }

################################################################################
# ENVIRONMENT
################################################################################
shell="$(ps c -p "$PPID" -o 'ucomm=' 2>/dev/null || true)"
shell="${shell##-}"
shell="${shell%% *}"
shell="$(basename "${shell:-$SHELL}")"

if [[ $shell != "bash" ]]; then
  # setup shell
  git_mvh_logerr "Not supported ${shell}, only bash,sh are supported"
  git_mvh_exit 1
fi

################################################################################
# The command line help
################################################################################
git_mvh_helpmenu() {
  git_mvh_logbold "GIT MVH"
  git_mvh_logline
  git_mvh_logline "Usage: git mvh [option...] [arg...]" >&2
  git_mvh_logline
  git_mvh_logbold " USAGE"
  git_mvh_logline
  git_mvh_logbold " FLAGS"
  git_mvh_logline
  git_mvh_logline "   -h, --help                  show this help menu"
  git_mvh_logline "   -v, --verbose               log verbose"
  git_mvh_logline
}
################################################################################
# CORE
################################################################################
# exit with code
git_mvh_exit() {
  exit $1
}
# is path  drectory
git_mvh_is_dir() {
  if [[ -d $1 ]] && [[ -n $1 ]] ; then
    return 0
  else
    return 1
  fi
}
# file exists
git_mvh_file_exists() {
  if [[ -f $1 ]] && [[ -n $1 ]] ; then
    return 0
  else
    return 1
  fi
}
################################################################################
# GIT-RMH
################################################################################
git_mvh_exec() {
  # from path
  local from=$1
  local from_is_dir=0
  if git_mvh_is_dir $1; then
    from_is_dir=1
  fi
  # to path
  local to=$2
  local to_is_dir=0
  if git_mvh_is_dir $2; then
    to_is_dir=1
  fi
  # is from dir ?
  git_mvh_logdebug "repository: ${GIT_MVH_REPO} "
  git_mvh_logdebug "from: ${from} "
  git_mvh_logdebug "from_is_dir: ${from_is_dir} "
  git_mvh_logdebug "to: ${to} "
  git_mvh_logdebug "to_is_dir: ${to_is_dir} "

  if [[ $from_is_dir -eq 0 ]] && ! git_mvh_file_exists $from; then
    git_mvh_logerr "from path invalid: $from"
    git_mvh_exit 2;
  fi

  git_mvh_loginfo "git renaming (${from}) to (${to})"
  # go ahead
  dir=`echo $to | grep -q '/$' && echo $to || dirname $to`
  [ ! -e "$from"   ] && usage "error: $src does not exist"

  GIT_MVH_FILTER="$GIT_MVH_FILTER                     \n\
    if [ -e \"$from\" ]; then                         \n\
      echo                                            \n\
      if [ ! -e \"$dir\" ]; then                      \n\
        mkdir -p ${GIT_MVH_VERBOSE} \"$dir\" && echo  \n\
      fi                                              \n\
      mv \"$from\" \"$to\"           \n\
    fi                                                \n\
  "
  if [[ $GIT_MVH_DRYRUN -eq 1 || $GIT_MVH_VERBOSE -eq 1 ]]; then
    git_mvh_logline
    git_mvh_loginfo "tree-filter to execute against $GIT_MVH_REPO"
    git_mvh_loginfo -e "$GIT_MVH_FILTER"
  fi
  [ $GIT_MVH_DRYRUN -eq 0 ] && git filter-branch -f --tree-filter "`echo -e $GIT_MVH_FILTER`" && git_mvh_loginfo "run: git push -f to push these changes to your repo!"
}
################################################################################
# Parse arguments and flags
################################################################################
CMDS=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    -v | --verbose)
      GIT_MVH_VERBOSE=1;
      shift 1;;
    -d | --dry-run)
      GIT_MVH_DRYRUN=1;
      shift 1;;
    -h | --help)
      git_mvh_helpmenu
      git_mvh_exit 0;;
    -*)
      git_mvh_logerr "unknown option: $1";
      git_mvh_exit 1;;
    *)
    CMDS+=("$1")
    shift 1;;
  esac
done

################################################################################
# run command
################################################################################
if [ ${#CMDS[@]} -eq 0 ]; then
  CMDS+=("help")
  CMDS+=("-")
fi

################################################################################
# EXECUTE
################################################################################
[ ! -d .git ] && git_mvh_logerr "error: git mvh must be ran from within the root of the repository" && git_mvh_exit 1;

git_mvh_exec "${CMDS[@]}"
