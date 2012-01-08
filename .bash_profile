# export operating system type

if [[ -n "${OSTYPE}" ]]; then
  export OSTYPE
fi

# clear arguments temporarily

arguments=( "$@" )
set --

# default shopt settings

if [[ -n "${PS1}" ]]; then
  shopt -s checkwinsize
  shopt -s checkhash
  shopt -s extglob
  shopt -s no_empty_cmd_completion
  shopt -u sourcepath
fi

# set HOSTNAME correctly (override with $HOME/.hostname)

if [[ -r "${HOME}/.hostname" ]]; then
    export HOSTNAME=`cat "${HOME}/.hostname"`
else
    export HOSTNAME=`hostname -s`
fi

# get cached values, if any

# cache_file="${HOME}/.bash_cache.${HOSTNAME}"
# if [[ -r "${cache_file}" && "${cache_file}" -nt "${BASH_SOURCE[0]}" ]]; then
  # eval "$(awk '/ \(\) $/ { print $1 }' "${cache_file}" | xargs echo "unset -f")"
  # source "${cache_file}" # 2>&1 | grep -v ': readonly variable'
  # if [[ "$(type -t resource)" == "function" ]]; then
    # resource -i "${cache_file}" bash_cache 2>&1 | grep -v ': readonly variable'
  # fi
  # unset cache_file
# fi

# ls functions

if [[ "$(type -a ls)" != "function" ]]; then
  unalias ls >/dev/null 2>&1
  if [[ "${OSTYPE}" == *linux* ]]; then
    function ls() { 
      command ls -F --color=auto "$@"
    }
    type -p dircolors >/dev/null 2>&1 && eval "`dircolors -b`"
  else
    function ls() { 
      command ls -FG "$@"
    }
  fi
fi

[[ -r ~/Documents/src/perl5/etc/bashrc ]] && source ~/Documents/src/perl5/etc/bashrc

# set up $TMP/$TMPDIR

if [[ -z "${TMP}" ]]; then
  [[ -n "${TEMPDIR}" ]] && TMP="${TEMPDIR}"
  [[ -n "${TMPDIR}" ]] && TMP="${TMPDIR}"
  TMP="${TMP:-/tmp}"
  if [[ "${TMP}" == /tmp && -n "${UID}" ]]; then
    TMP="/tmp/${UID}"
    [[ -d "${TMP}" ]] || mkdir "${TMP}" >/dev/null 2>&1
    chmod 700 "${TMP}" >/dev/null 2>&1
  fi
fi
export TMP
export TEMPDIR="${TEMPDIR:-${TMP}}"
export TMPDIR="${TMPDIR:-${TMP}}"

# get system paths

if [[ -x "${HOME}/bin/path_helper" ]]; then
    eval `${HOME}/bin/path_helper`
elif [[ -x "/usr/libexec/path_helper" ]]; then
    export PATH=""
    export MANPATH=""
    eval `/usr/libexec/path_helper -s`
else
    prepend_path /opt/local/sbin /opt/local/bin
    append_path /usr/local/bin "${HOME}/bin"
    [[ -d "/opt/local/share/man" && ":${MANPATH}:" != *:"/opt/local/share/man":* ]] && export MANPATH="/opt/local/share/man:${MANPATH}"
fi

if [[ -d /home/y ]]; then
  export ROOT=/home/y
  export CVSROOT=vault.yahoo.com:/CVSROOT
  export CVS_RSH=ssh
  export SVN_SSH="/usr/local/bin/yssh"
  export SVN_EDITOR="/bin/vi"
  export SVNROOT="svn+ssh://svn.corp.yahoo.com"
  export SRCZIP="svn"
fi

# ensure history is saved

if [[ -n "${PS1}" ]]; then
  if [[ -f "${HOME}/.shared_home" ]]; then
    HISTFILE="${HOME}/.bash_history.${HOSTNAME}"
    HISTFILESIZE=2000
  else
    [[ -h "${HOME}/.bash_history" ]] && rm -f "${HOME}/.bash_history"
    [[ -h "${HOME}/.history" ]] && rm -f "${HOME}/.history"
    HISTFILE="${HOME}/.bash_history"
    HISTFILESIZE=500
  fi
  HISTSIZE=500
  HISTTIMEFORMAT="%Y%m%d-%H%M%S "
  shopt -s histappend
fi

# set functions

if [[ -f "${HOME}/.bash_functions" ]]; then
  source "${HOME}/.bash_functions"
fi

if [[ "$(type -t igor)" != "function" ]]; then
  if [[ -x "/home/y/bin/igor" && -x "/home/y/bin/ig" ]]; then
    unalias igor >/dev/null 2>&1
    function igor() { /home/y/bin/ig "$@"; }
  fi
fi

if [[ -z "${GREP_OPTIONS}" ]]; then
  if grep --color=auto root /etc/passwd >/dev/null 2>&1; then
    export GREP_OPTIONS="--color=auto"
  fi
fi

# set TERM and title correctly on Mac OS X

#if [[ "${TERM_PROGRAM}" == "Apple_Terminal" && "${TERM}" == xterm* ]]; then
#    if [[ -x "${HOME}/bin/title" ]]; then
#        "${HOME}/bin/title" "${USER}@${HOSTNAME}"
#    fi
#fi

# create an alias for "cd" that looks in ~/.dirs for symlinks to
# directories as shortcuts.  something similar could be done by
# setting CDPATH to "${HOME}/.dirs" but this ensures the physical path
# is used by the shell...
if [[ -d "${HOME}/.dirs" ]]; then
  #export CDPATH=".:${HOME}/.dirs"
  _cd_wrapper() {
    local f="${FUNCNAME[1]}" # the name of the function that called this one
    local d="${1:-${HOME}}"; shift
    if [[ -d "${d}" ]]; then
      builtin "${f}" "${d}"
    elif [[ "${d}" != */* && -d "${HOME}/.dirs/${d}" ]]; then
      builtin "${f}" -P "${HOME}/.dirs/${d}"
    elif [[ -f "${d}" ]]; then
      builtin "${f}" "$(dirname "${d}")"
    else
      builtin "${f}" "${d}"
    fi
  }
  cd() {
    _cd_wrapper "$@"
  }
  pushd() {
    _cd_wrapper "$@"
  }
  popd() {
    _cd_wrapper "$@"
  }
fi

unset -f with_lock_file
with_lock_file() {
  local file="$1"; shift
  local rc=1
  if ( set -o noclobber; echo "$$" > "${file}") 2>/dev/null; then
    trap 'rm -f "${file}"; exit $?' INT TERM EXIT
    eval "$@"
    rc="$?"
    rm -f "${file}"
    trap - INT TERM EXIT
  fi
  return $rc
}

unset -f remember_in_file
remember_in_file() {
  local file="$1"; shift
  local thing="$1"; shift
  if ( set -o noclobber; echo "${thing}" > "${file}" ) 2>/dev/null; then
    return 0
  else
    with_lock_file "${file}.lock" "grep -F -x \"${thing}\" \"${file}\" >/dev/null 2>&1 || ( echo \"${thing}\" >> \"${file}\" )"
  fi
}

unset -f already_in_file
already_in_file() {
  local file="$1"; shift
  local thing="$1"; shift
  with_lock_file "${file}.lock" "grep -F -x \"${thing}\" \"${file}\" >/dev/null 2>&1"
}

unset -f find_binary
find_binary() {
  local var="$1"; shift
  local args=""
  if [[ -n "$1" && "$1" == --args=* ]]; then
    args="$1"; shift
    args=" ${args#--args=}"
  fi
  while [[ -n "$1" ]] && ! type -p "$1" >/dev/null 2>&1; do
    shift
  done
  if [[ -n "$1" ]]; then
    local filepath="$(type -p "$1")"
    if [[ $? == 0 ]]; then
      eval "$(printf "export %s=%q\n" "${var}" "${filepath}${args}")"
      return 0
    fi
  fi
  return 1
}

# unset -f find_file
# find_file() {
#   local filename="$1"; shift
#   while [[ -n "$1" && ! -e "$1/${filename}" ]]; do
#     shift
#   done
#   if [[ -n "$1" && -e "$1/${filename}" ]]; then
#     echo "$1/${filename}"
#     return 0
#   else
#     return 1
#   fi
# }

# standard variables

if [[ -z "${EDITOR}" ]]; then
  find_binary EDITOR vim vi
  export EDITOR
fi

if [[ -z "${PAGER}" ]]; then
  find_binary tmp_pager less more
  if [[ "${tmp_pager}" == */less ]]; then
    export PAGER="${tmp_pager} -R"
    export PERLDOC_PAGER="${tmp_pager} -RS"
  else
    export PAGER="${tmp_pager}"
    export PERLDOC_PAGER="${tmp_pager}"
  fi
  unset tmp_pager
fi

if [[ -z "${LANG}${LC_ALL}" && "${OSTYPE}" != "freebsd4.11" ]]; then
  export LANG=en_US.UTF-8
  export LC_ALL=en_US.UTF-8
fi

if [[ -z "${FCEDIT}" ]]; then
  find_binary FCEDIT --args="-w" mate
  export FCEDIT
fi

# completion

if [[ -z "${BASH_COMPLETION}" && -f /opt/local/etc/bash_completion ]]; then
  . /opt/local/etc/bash_completion
fi

if [[ "$(type -t ri)" != "function" ]]; then
  if type -p qri >/dev/null 2>&1 ; then
    function ri() {
      qri --pager-cmd "less -R -S -c -z-10" -f ansi -w 140 "$@"
    }
  elif type -p ri > /dev/null 2>&1 ; then
    function ri() {
      env PAGER="less -R -S -c -z-10" ri -f ansi -w 140 "$@"
    }
  fi
fi

# get yroot info

if [[ -z "${YROOT_NAME}" ]]; then
  if [[ -h /.yroot ]]; then
    export YROOT_NAME="$(basename $(readlink /.yroot))"
    if [[ -f /.yroot_host ]]; then
      export YROOT_HOST="$(</.yroot_host)"
    fi
  fi
fi

# set up prompt

if [[ -n "$PS1" && "${PS1}" != *"\[0m"* ]]; then

  hostname_to_title() {
    hostname="$1"
    hostname="${hostname/.omg.ent./.OMG.}"
    hostname="${hostname/.movies./.M.}"
    hostname="${hostname/.stage.omg.pool./.S-OMG.}"
    hostname="${hostname/.stage./.St.}"
    hostname="${hostname/.perf./.P.}"
    hostname="${hostname/.finance./.F.}"
    hostname="${hostname/.sports./.Sp.}"
    hostname="${hostname/.shine.lifestyles./.SHINE.}"
    hostname="${hostname/.global.media./.GM.}"
    hostname="${hostname/.media./.M.}"
    hostname="${hostname/%.corp.yahoo.com/.C}"
    hostname="${hostname/%.yahoo.com/}"
    hostname="${hostname/#slowsnowcall-dm/SSC}"
    hostname="${hostname/#plantmayor./PM.}"
    echo "${hostname}"
  }
  shortened_hostname() {
    hostname="$1"
    hostname="${1/%.yahoo.com/}"
    echo "${hostname}"
  }

  interactive_prompt() {
    local hostname="$(shortened_hostname "$(hostname)")"
    local timestamp="\$(date +%Z\\ %Y-%m-%d\\ %H:%M:%S)"
    local reverse="\\[\e[0;30;47m\\]"
    local bold_reverse="\\[\e[0;30;47m\\]"
    local reset="\\[\e[0m\\]"
    local prompt="${reverse}[\u@${bold}${hostname}${reverse}"
    if [[ -n "${YROOT_NAME}" ]]; then
      prompt="${prompt}:$YROOT_NAME"
    fi
    if [[ -n "${WINDOW}" ]]; then
      prompt="${prompt}(${WINDOW})"
    fi
    if [[ "${TERM}" == *screen* || "${TERM}" == xterm-256color ]]; then
      prompt="${prompt}\\[\ek$(hostname_to_title "$(hostname)")\e\\\\\\]"
    fi
    prompt="${prompt} \W]${reset}\\$ "
    echo "${prompt}"
  }

  PS1="$(interactive_prompt)"

  unset -f interactive_prompt
  unset -f hostname_to_title
  unset -f shortened_hostname
fi

# canonical name, given a search path

canonical_hostname() {
  local name
  local fqdn
  local passthrough=1
  local -a domain_search_path=( "." ".yahoo.com." ".corp.yahoo.com." ".plambert.net." )
  if [[ -n "$1" && "$1" == "-f" ]]; then
    unset passthrough
  fi
  name="$1"; shift
  if [[ "${name}" == *. ]]; then
    fqdn="${name}"
  else
    for search_domain in ${domain_search_path[@]}; do
      fqdn="${name}${search_domain}"
      if host "${fqdn}" 2>&1 | grep -v -i 'not found' >/dev/null 2>&1; then
        break
      fi
      unset fqdn
    done
  fi
  if [[ -n "${fqdn}" ]]; then
    echo "${fqdn:-${name}}"
    return 0
  else
    echo "${name}"
    return 1
  fi
}

# set up ssh briefcase

BRIEFCASE="$HOME/.briefcase";   # File containing a list of files to copy to
                                # remote host

unset -f ssh

if type -p ssh >/dev/null 2>&1; then
  __SSH="$(type -p ssh)"
else
  unset __SSH
fi

if [[ -n "$__SSH" ]]; then
  ssh() {
    # First: Determine the hostname argument.

    # Skip all the command line arguments using getopts (shell builtin).
    # This will set $OPTIND to the index of the first non-option argument,
    # which should be the hostname argument to ssh, if provided.
    #
    # N.B.: This option list is current as of OpenSSH 4.5p1, and may need
    # to be updated as newer versions are released.

    local sshargs="$@" Option hn
    #OPTIND=0

    #while getopts '1246AaCfgkMNnqsTtVvXxYb:c:D:e:F:i:L:l:m:O:o:p:R:S:w:' Option; do
      #:
    #done
    #shift $(($OPTIND - 1))
    #unset OPTIND OPTERR

    # $1 should now be either the hostname or empty
    #if [[ -n "$1" ]]; then
      #hn="$(canonical_hostname "${1#*@}")"
      #[[ "$1" == *@* ]] && hn="${1%@*}@${hn}"
      #shift
    #fi
    if [[ $# -ne 1 || "$1" == *@* ]]; then
      # No hostname specified, a remote command is specified, or host is not in the yahoo.com network:
      # Run ssh as specified.
      $__SSH "$@"
    else
      # Copy our environment to the target host ($1)'s home directory.
      # We run rsync with -u so that any newer files on the target
      # host are preserved.  All files to be synced to the target host
      # should be listed, one per line, in $HOME/.briefcase.
      hn="$(canonical_hostname "${1#*@}")"
      echo -n "Syncing... " 1>&2
      if rsync -quptgoL -e "${__SSH}" --files-from=$BRIEFCASE "$HOME" "${hn}":; then
        if [[ -z "$1" ]] && ! already_in_file "${HOME}/.briefcase.synced_hosts" "${hn}"; then
          remember_in_file "${HOME}/.briefcase.synced_hosts" "${hn}"
        fi
        echo "done" 1>&2
        # Now run ssh, with the command line intact.
        echo "Connecting..." 1>&2
        $__SSH "${hn}"
      else
        echo "Briefcase sync failed: $?" >&2
      fi

    fi
  }
fi

# set up ssh-agent

if [[ -n "${PS1}" && -f "${HOME}/.ssh-agent-hosts" ]] && already_in_file "${HOME}/.ssh-agent-hosts" "$(hostname)" >/dev/null 2>&1; then
  ssh_agent_setup() {
    local agent_file="${HOME}/.ssh-agent.$(hostname)"
    local launch_agent="$(/bin/ls -t /tmp/launch-*/Listeners 2>/dev/null | head -1)"
    if [[ -e "${launch_agent}" ]]; then
      echo export SSH_AUTH_SOCK="\"${launch_agent}\"" > "${agent_file}"
    fi
    if [[ -f "${agent_file}" ]]; then
      if [[ -n "$PS1" ]]; then
        . "${agent_file}"
      else
        . "${agent_file}" >/dev/null 2>&1
      fi
    fi
    ssh-add -l >/dev/null 2>&1
    local rc=$?
    if [[ "${rc}" == 2 ]]; then
      ssh-agent > "${agent_file}"
      . "${agent_file}"
      ssh-add -l >/dev/null 2>&1
      rc="$?"
    fi
    if [[ "${rc}" == 1 ]]; then
      if ssh-add -h 2>&1 | grep ' -t life' >/dev/null 2>&1; then
        ssh-add -t $(( 4 * 60 * 60 ))
      else
        ssh-add
      fi
    elif [[ "${rc}" == 0 ]]; then
      ssh-add -l
    fi
  }

  ssh_agent_setup
  unset -f ssh_agent_setup
fi

if [[ -z "${ONEPASSWDKEYCHAIN}" ]]; then
  kc1p="${HOME}/Dropbox/Private/1Password.agilekeychain"
  if [[ -d "${kc1p}" ]]; then
    export ONEPASSWDKEYCHAIN="${HOME}/Dropbox/Private/1Password.agilekeychain"
  fi
  unset kc1p
fi

# set up auto-updating of .bash_profile

if [[ -n "${PS1}" && -z "${__resource_path_bash_profile}" ]]; then
  if [[ "$(type -t "resource")" == "function" ]]; then
    export PROMPT_COMMAND="resource"
    resource -v -i "${BASH_SOURCE[0]}" bash_profile
  fi
fi

if type -f npm > /dev/null 2>&1; then
  export NODE_PATH=/usr/local/lib/node_modules
fi

set -- "${arguments[@]}"
unset arguments

# if [[ -n "${cache_file}" ]]; then
  # echo "# caching of bash startup stuff; do not edit!" > "${cache_file}.tmp"
  # echo "# remove to rebuild" >> "${cache_file}.tmp"
  # shopt -p >> "${cache_file}.tmp"
  # # output of declare can't be used directly, since it includes readonly values...
  # # so, we strip those.  we also make function definitions explicit, to avoid problems in redefining them.
  # # this makes this:
  # #   foo () 
  # #   {
  # #     ...
  # #   }
  # # into:
  # #   # define function foo :
  # #   function foo () {
  # #     ...
  # #   }
  # (readonly; declare -p) \
  # | perl -ne '
      # if (/^(declare -\S+ (\S+?))=.*$/) {
        # $declare{$2}=$1;
      # }
      # elsif ($skip_func) {
        # $skip_func=1 if (/^\}/);
      # }
      # else {
        # s/^(\S+) \(\)\s*$/# define function $1 :\nfunction $1 () /; 
        # s/^(BASH_COMPLETION\S*)=/[[ -n "\${$1}" ]] || $declare{$1}=/;
        # print unless (/ ^
                        # ( 
                          # __resource           \S*
                        # | BASH (?!_COMPLETION) \S*
                        # | SSH                  \S*
                        # | TERM                 \S*
                        # | STY
                        # | UID
                        # | EUID
                        # | PPID
                        # | SHELLOPTS
                        # | PROMPT_COMMAND
                        # | PWD
                        # | OLDPWD
                        # | bash[0-9]+           \S*
                        # )
                        # = 
                     # /x )
      # }' \
  # >> "${cache_file}.tmp"
  # # | grep -E -v '^(__resource_[^[:space:]]*|BASH_[^[:space:]]*|SSH_[^[:space:]]*|TERM[^[:space:]]*|STY|UID|EUID|PPID|SHELLOPTS|PROMPT_COMMAND|bash[0-9]+b?)=' \
  # mv -f "${cache_file}.tmp" "${cache_file}" >/dev/null 2>&1
  # unset cache_file
# fi

