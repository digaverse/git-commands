#!/bin/bash

# [-e] instruct bash to exit if any command [1] has a non-zero exit status.
# [-o] prevent errors in a pipeline from being masked.
# [-u] fail if found references to any variable which was not previously defined
set -euo pipefail

################################################################################
# GLOBAL VARS
################################################################################
GIT_RMH_VERBOSE=0
GIT_RMH_DRYRUN=0
GIT_RMH_WD="$(pwd)"
GIT_RMH_NAME="git-rmh"
GIT_RMH_REPO=$(basename `git rev-parse --show-toplevel`)
GIT_RMH_SUPPORTED_ENV=("bash", "sh", "git")

################################################################################
# CORE
################################################################################
# exit with code
git_rmh_exit() {
  exit $1
}
# is path  drectory
git_rmh_is_dir() {
  if [[ -d $1 ]] && [[ -n $1 ]] ; then
    return 0
  else
    return 1
  fi
}
# file exists
git_rmh_file_exists() {
  if [[ -f $1 ]] && [[ -n $1 ]] ; then
    return 0
  else
    return 1
  fi
}

################################################################################
# LOG
################################################################################
git_rmh_loginfo() { printf "\033[94m%s\033[0m %s\n" "[$GIT_RMH_NAME]:" "$*"; }
git_rmh_logerr() { printf "\033[91m%s\033[0m %s\n" "[$GIT_RMH_NAME]:" "$*" >&2; }
git_rmh_logwarn() { printf "\033[33m%s\033[0m %s\n" "[$GIT_RMH_NAME]:" "$*"; }
git_rmh_logok() { printf "\033[32m%s\033[0m %s\n" "[$GIT_RMH_NAME]:" "$*"; }
git_rmh_logline() { printf "%s\n" "$*"; }
git_rmh_logdebug() {
  if [ $GIT_RMH_VERBOSE -gt 0 ]; then
    printf "\033[2m%s\033[0m %s\n" "[$GIT_RMH_NAME]:" "$*";
  fi
}
git_rmh_logmute() { printf "\033[39m%s\033[0m\n" "$*"; }
git_rmh_logbold() { printf "\033[1m%s\033[0m\n" "$*"; }
git_rmh_helpcmd() { printf "\033[1m  %-15s\033[0m %s\n" "$1" "$2"; }

################################################################################
# ENVIRONMENT
################################################################################
shell="$(ps c -p "$PPID" -o 'ucomm=' 2>/dev/null || true)"
shell="${shell##-}"
shell="${shell%% *}"
shell="$(basename "${shell:-$SHELL}")"

# check shell
if [[ ! " ${GIT_RMH_SUPPORTED_ENV[@]} " =~ "${shell}" ]]; then
  git_rmh_logerr "Not supported ${shell}, only bash,sh are supported"
  git_rmh_exit 1
fi

################################################################################
# The command line help
################################################################################
git_rmh_helpmenu() {
  git_rmh_logbold "GIT RMH"
  git_rmh_logline
  git_rmh_logline "Usage: git rmh [option...] [arg...]" >&2
  git_rmh_logline
  git_rmh_logbold " USAGE"
  git_rmh_logline
  git_rmh_logbold " FLAGS"
  git_rmh_logline
  git_rmh_logline "   -h, --help                  show this help menu"
  git_rmh_logline "   -v, --verbose               log verbose"
  git_rmh_logline
}

################################################################################
# GIT-RMH
################################################################################
git_rmh_exec() {
  if [[ $1 == "help" ]]; then
    git_rmh_helpmenu;
    git_rmh_exit 0;
  fi
  # remove path
  local remove=$1
  local remove_is_dir=0
  if git_rmh_is_dir $1; then
    remove_is_dir=1
  fi
  git_rmh_loginfo "repository: ${GIT_RMH_REPO} "
  git_rmh_loginfo "remove: ${remove} "
  git_rmh_logdebug "is_dir: ${remove_is_dir} "

  [ ! -e "$remove"   ] && usage "error: $remove does not exist"

  if [[ $GIT_RMH_DRYRUN -eq 1 || $GIT_RMH_VERBOSE -eq 1 ]]; then
    git_rmh_logline
    git_rmh_loginfo "index-filter to execute against $GIT_RMH_REPO"
  fi

  if [[ $GIT_RMH_DRYRUN -eq 0 ]]; then
    git filter-branch -f --index-filter \
      "git rm --cached --ignore-unmatch $remove" \
      --prune-empty --tag-name-filter cat -- --all
    git for-each-ref --format="delete %(refname)" refs/original | git update-ref --stdin
    git reflog expire --expire=now --all
    git gc --prune=now
    git_rmh_loginfo "run: git push -f --all && git push -f --tags to push these changes to your repo!"
  fi
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
      git_rmh_helpmenu
      git_rmh_exit 0;;
    -*)
      git_rmh_logerr "unknown option: $1";
      git_rmh_exit 1;;
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
[ ! -d .git ] && git_rmh_logerr "error: git rmh must be ran from within the root of the repository" && git_rmh_exit 1;

git_rmh_exec "${CMDS[@]}"
