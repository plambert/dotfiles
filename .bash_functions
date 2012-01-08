# common bash functions, to be sourced into a script
# no #! line on purpose, don't run this directly!  :-)

# $Id: bash_functions 82 2007-05-14 17:46:53Z plambert $
# $HeadURL: svn+ssh://svn@skippy.plambert.net/repos/ssh_host/trunk/bash_functions $

DEFAULT_TEMP_DIR="/tmp/${UID}"
DEFAULT_SSH_AUTH_SOCK="${DEFAULT_TEMP_DIR}/ssh-agent.socket"
ALT_SSH_AUTH_SOCK="${DEFAULT_TEMP_DIR}/SSHKeychain.socket"
DEFAULT_SSH_AGENT_FILE="${HOME}/.sshagent"

#unset -f ssh
#ssh() {
#    ssh_add
#    /usr/bin/ssh "$@"
#}

unset -f ssh_add
ssh_add() {
    if [[ -z "$*" ]]; then
        ensure_ssh_agent_has_keys
    else
        /usr/bin/ssh-add "$@"
    fi
}

unset -f ssh_agent_has_keys
ssh_agent_has_keys() {
    /usr/bin/ssh-add -l >/dev/null 2>&1
}

unset -f ssh_agent_is_running
ssh_agent_is_running() {
    local sock
    local rc
    if [[ -n "$1" ]]; then
        sock="$1"
        if [[ ! -e "${sock}" ]]; then
            return 1
        fi
    else
        sock="${SSH_AUTH_SOCK}"
    fi
    SSH_AUTH_SOCK="${sock}" /usr/bin/ssh-add -l >/dev/null 2>&1
    rc=$?
    if [[ $rc == 2 ]]; then
        return 1
    else
        return 0
    fi
}

unset -f ensure_ssh_agent_has_keys
ensure_ssh_agent_has_keys() {
    if [[ -t 0 && -t 1 ]]; then
        start_ssh_agent
        if ! ssh_agent_has_keys; then
            /usr/bin/ssh-add
            while ! ssh_agent_has_keys; do
                /usr/bin/ssh-add
            done
        else
            echo SSH Keys:
            /usr/bin/ssh-add -l
        fi
    else
        # not a tty!
        return 0
    fi
}

unset -f _new_ssh_agent
_new_ssh_agent() {
    local sock="$1"
    if [[ -n "${sock}" ]]; then
        sock="${DEFAULT_SSH_AUTH_SOCK}"
    fi
    unset SSH_AUTH_SOCK
    if [[ ! -e "${DEFAULT_TEMP_DIR}" ]]; then
        mkdir -m 0700 "${DEFAULT_TEMP_DIR}"
    elif [[ ! -d "${DEFAULT_TEMP_DIR}" ]]; then
        echo "Cannot create temp directory '${DEFAULT_TEMP_DIR}' as it already exists!" 1>&2
        return 1
    fi
    /usr/bin/ssh-agent -t 4h -a /tmp/${UID}/ssh-agent.socket > "${DEFAULT_SSH_AGENT_FILE}"
    . "${DEFAULT_SSH_AGENT_FILE}"
}

unset -f start_ssh_agent
start_ssh_agent() {
    if ssh_agent_has_keys; then
        return 0;
    fi
    if ! ssh_agent_is_running; then
        if ssh_agent_is_running "${DEFAULT_SSH_AUTH_SOCK}"; then
            export SSH_AUTH_SOCK="${DEFAULT_SSH_AUTH_SOCK}"
        elif ssh_agent_is_running "${ALT_SSH_AUTH_SOCK}"; then
            export SSH_AUTH_SOCK="${ALT_SSH_AUTH_SOCK}"
        else
            _new_ssh_agent "${DEFAULT_SSH_AUTH_SOCK}"
        fi
        if ! ssh_agent_is_running; then
            echo "Failed to start ssh-agent!" 1>&2
            return 1
        fi
    fi
}

unset -f huh
huh() {
  local f
  for f in "$@"; do
    case $(type -t "${f}") in
      file     ) _huh_file "${f}" ;;
      function ) type      "${f}" ;;
      builtin  ) type      "${f}" ;;
      *        ) type      "${f}" ;;
    esac
  done
}

unset -f _huh_file
_huh_file() {
  local f="$1"
  local t
  if [[ "$(type -a "${f}" 2>/dev/null | wc -l)" > 1 ]]; then
    echo "Multiple files found:"
    type -a "${f}"
  else
    f="$(type -p "${f}")"
    t="$(file "${f}")"
    if [[ "${t}" == *[sS][cC][rR][iI][pP][tT]* ]]; then
      less "${f}"
    else
      echo "${t}"
    fi
  fi
}

# output the length of the given array
unset -f pml_length
pml_length() {
  local _pml_ary="$1"; shift
  eval "echo \"\${#${_pml_ary}[@]}\""
}

# output the last index of the given array
# note that indices do NOT have to be contiguous.  an array of size 7 might have a last index of 10,000!
unset -f pml_last_index
pml_last_index() {
  local _pml_ary="$1"; shift
  local _pml_indices
  eval "_pml_indices=( \"\${!${_pml_ary}[@]}\" )"
  echo "${_pml_indices[$(( ${#_pml_indices[@]} - 1 ))]}"
}

# push args onto an array
unset -f pml_push
pml_push() {
  local _pml_ary="$1"; shift
  local last=$(pml_last_index ${_pml_ary})
  local arg
  for arg in "$@"; do
    last=$(( last + 1 ))
    eval "${_pml_ary}[${last}]=\"\${arg}\""
  done
  #eval "${_pml_ary}=(\"\${${_pml_ary}[@]}\" \"\$@\")"
  eval "echo \"\${${_pml_ary}[@]}\""
}

# pop args off of an array
unset -f pml_pop
pml_pop() {
  local _pml_ary="$1"; shift
  # last=$((${#ary[@]}-1))
  local last=$(( $(pml_length ${_pml_ary}) - 1 ))
  if [[ "${last}" -ge 0 ]]; then
    # ary=("$ary[@]:0:${last}}")
    local val="$(eval "echo \"\${${_pml_ary}[${last}]}\"")"
    eval "${_pml_ary}=(\"\${${_pml_ary}[@]:0:${last}}\")"
    echo "${val}"
  fi
}

# shift args off of an array
unset -f pml_shift
pml_shift() {
  local _pml_ary="$1"; shift
  local last=$(( $(pml_length ${_pml_ary}) - 1 ))
  if [[ "${last}" -ge 0 ]]; then
    # ary=("${ary[@]:1}")
    eval "echo \"\${${_pml_ary}[0]}\""
    eval "${_pml_ary}=(\"\${${_pml_ary}[@]:1}\")"
  fi
}

# unshift args onto an array
unset -f pml_unshift
pml_unshift() {
  local _pml_ary="$1"; shift
  local last=$(( $(pml_length ${_pml_ary}) - 1 ))
  if [[ "${last}" -ge 0 ]]; then
    # ary=("$@" "${ary[@]}")
    eval "${_pml_ary}=(\"\$@\" \"\${${_pml_ary}[@]}\")"
    eval "echo \"\${${_pml_ary}[@]}\""
  fi
}

unset -f f0
f0() {
  local find_args=( )
  local xargs_args=( )
  local opt
  local ends_with_print=""
  while [[ -n "$1" && "$1" != "--" ]]; do
    opt="$1"; shift
    if [[ "${opt}" == "-print" ]]; then
      opt="-print0"
    fi
    if [[ "${opt}" == "-print0" ]]; then
      ends_with_print="yes"
    else
      ends_with_print=""
    fi
    find_args=( "${find_args[@]}" "${opt}" )
  done
  if [[ -z "${ends_with_print}" ]]; then
    find_args=( "${find_args[@]}" "-print0" )
  fi
  shift
  while [[ -n "$1" ]]; do
    opt="$1"; shift
    xargs_args=( "${xargs_args[@]}" "${opt}" )
  done
  if [[ "${#xargs_args[@]}" -gt 0 ]]; then
    echo "+ find ${find_args[@]} | xargs -0 ${xargs_args[@]}"
    find "${find_args[@]}" | xargs -0 "${xargs_args[@]}"
  else
    echo "f0: must give find options, then xargs options, separated by --" 1>&2
    return 1
  fi
}

unset -f ps_grep
ps_grep() {
  local regexp
  local ps_options="auxww"
  local pids
  if [[ "$1" == -* || "$1" == aux* ]]; then
    ps_options="$1"; shift
  fi
  regexp="($1)"; shift
  while [[ -n "$1" ]]; do
    regexp="${regexp}|($1)"; shift
  done
  echo "REGEXP: ${regexp}"
  pids="$(killall -INFO -s -m "${regexp}" | awk '{print $3}' | paste -s -d, -)"
  echo "PIDS: ${pids}"
  ps "${ps_options}" -p "${pids}"
}

unset -f prepend_path
prepend_path() { 
  local p="${PATH}" 
  local dir
  for dir in "$@"; do 
    if [[ -d "${dir}" && ":${p}:" != *:"${dir}":* ]]; then 
      p="${dir}:${p}"
    fi
  done
  export PATH="${p}"
}

unset -f append_path
append_path() {
  local p="${PATH}"
  local dir
  for dir in "$@"; do
    if [[ -d "${dir}" && ":${p}:" != *:"${dir}":* ]]; then
      p="${p}:${dir}"
    fi
  done
  export PATH="${p}"
}

# get the mtime of a file (uses stat, which varies by OS)
unset -f mtime
mtime() {
  local file="$1"; shift
  if [[ -e "${file}" ]]; then
    if [[ "${OSTYPE}" == *linux* ]]; then
      stat -c %Y "${file}"
    else
      stat -f %m "${file}"
    fi
  else
    echo 0
    return 1
  fi
}

# get the age of a file in seconds (uses mtime())
unset -f file_age
file_age() {
  local file="$1"; shift
  local last_mod
  last_mod=$(mtime "${file}")
  echo "$(date +%s) - ${last_mod}" | bc -l
}

# source a file, if it's not been sourced before, or it has changed since it was last sourced.
# -i means "implied," the file has already been sourced, and we're just adding it to the list.
unset -f resource
resource() {
  local sourcefile sourcename varpath vartime last_mod _resource_debug opt _resource_implied _resource_list
  local now="$(date +%s)"
  while [[ -n "$1" && "$1" == -* ]]; do
    opt="$1"; shift
    case "${opt}" in
      -d ) _resource_debug=yes  ;;
      -i ) _resource_implied=yes ;;
      -l ) _resource_list=yes ;;
    esac
  done
  if [[ -n "${_resource_list}" ]]; then
    for varpath in ${!__resource_path_*}; do
      vartime="__resource_time_${varpath#__resource_path_}"
      last_mod=$(mtime "${!varpath}")
      printf "%q (%q) updated %d seconds ago\n" "${varpath#__resource_path_}" "${!varpath}" $(( $now - $last_mod ))
    done
    return 0
  fi
  if [[ -n "$2" ]]; then
    sourcefile="$1"; shift
    sourcename="$1"; shift
    vartime="__resource_time_${sourcename}"
    varpath="__resource_path_${sourcename}"
    if [[ -n "${_resource_implied}" ]]; then
      eval "export ${vartime}=\$(mtime \"\${sourcefile}\")"
      [[ -n "${_resource_debug}" ]] && echo "+ ${vartime}=${!vartime}" 1>&2
    elif [[ -z "${!vartime}" ]]; then
      eval "export ${vartime}=0"
      [[ -n "${_resource_debug}" ]] && echo "+ ${vartime}=${!vartime}" 1>&2
    fi
    eval "$(printf "export %s=%q\n" "${varpath}" "${sourcefile}")"
    [[ -n "${_resource_debug}" ]] && printf "+ %s=%q\n" "${varpath}" "${sourcefile}" 1>&2
  fi
  if [[ -n "${_resource_implied}" ]]; then
    # echo "+ short-circuiting resource: ${sourcename} ${sourcefile}"
    return 0
  fi
  for varpath in ${!__resource_path_*}; do
    vartime="__resource_time_${varpath#__resource_path_}"
    last_mod=$(mtime "${!varpath}")
    [[ -n "${_resource_debug}" ]] && printf "%s=%s, %s=%d seconds ago, last_mod=%d seconds ago, " "${varpath}" "${!varpath}" "${vartime}" $(( $now - ${!vartime} )) $(( $now - $last_mod )) 1>&2
    if [[ "${!vartime}" -lt "${last_mod}" ]]; then
      [[ -n "${_resource_debug}" ]] && printf "re-sourcing, "
      [[ -z "${_resource_debug}" ]] && printf "%q updated %d seconds ago, reloading\n" "${!varpath}" $(( $now - $last_mod )) 1>&2
      source "${!varpath}"
      eval "export ${vartime}=${last_mod}"
      [[ -n "${_resource_debug}" ]] && printf "%s=%q\n" "${vartime}" "${last_mod}"
    else
      [[ -n "${_resource_debug}" ]] && echo "unchanged, skipped."
    fi
  done
}

pman () {
  man -t "$@" | ps2pdf - - | open -g -f -a /Applications/Preview.app
}
tman () {
  MANWIDTH=160 MANPAGER='col -bx' man "$@" | mate
}
# Quit an OS X application from the command line
quit () {
  local app
  for app in "$@"; do
    osascript -e "$(printf 'quit app %q' "${app}")"
  done
}
bman () {
  gunzip < `man -w "$@"` | groff -Thtml -man | bcat
}

# show a file (use less, if available, otherwise cat)
_show_file () {
  if type less >/dev/null 2>&1; then
    less -RS "$@"
  else
    cat "$@"
  fi
}

# show, edit, or append to the motd
motd () {
  local cmd="$1"; shift
  case "$cmd" in
    edit ) _motd_edit ;;
    append | app ) _motd_append "$@" ;;
    "" ) _show_file /etc/motd ;;
    * ) echo "usage: motd [edit|append]" ;;
  esac
}

# append text to the motd
_motd_append () {
  echo "$(date) (${USER}): $@" | sudo tee --append /etc/motd
}

# edit the motd
_motd_edit () {
  sudo "${EDITOR:-vi}" /etc/motd
}

# cm3 shortcuts
cm3 () {
  local cmd="$1"; shift
  case "$cmd" in
    start ) _cm3_start "$@" ;;
    restart ) _cm3_restart "$@" ;;
    stop ) _cm3_stop "$@" ;;
    status | stat ) _cm3_status "$@" ;;
    log | logs ) _cm3_log "$@" ;;
    * ) _cm3_help "$@" ;;
  esac
}

_cm3_help () {
  echo "usage: cm3 <start|stop|restart|status> [opts...]"
  echo "  start, stop, restart take an option of client, sync or all.  default is client."
}

_cm3_start () {
  local arg="$1"; shift
  case "$arg" in
    sync ) sudo /var/cm3/bin/svc -u /var/cm3/service/cm3_client_sync && _motd_append "started cm3_client_sync" ;;
    client | "" ) sudo /var/cm3/bin/svc -u /var/cm3/service/cm3_client && _motd_append "started cm3_client" ;;
    all ) _cm3_start sync; _cms_start client ;;
    * ) echo "optional argument must be sync, client, all"; return 1 ;;
  esac
}

_cm3_stop () {
  local arg="$1"; shift
  case "${arg}" in
    sync ) sudo /var/cm3/bin/svc -d /var/cm3/service/cm3_client_sync && _motd_append "downed cm3_client_sync" ;;
    client | "" ) sudo /var/cm3/bin/svc -d /var/cm3/service/cm3_client && _motd_append "downed cm3_client" ;;
    all ) _cms_stop client; _cms_stop sync ;;
    * ) echo "optional argument must be sync, client, all"; return 1 ;;
  esac
}

_cm3_restart () {
  local arg="$1"; shift
  case "${arg}" in
    sync ) sudo /var/cm3/bin/svc -t /var/cm3/service/cm3_client_sync && _motd_append "restarted cm3_client_sync" ;;
    client | "" ) sudo /var/cm3/bin/svc -t /var/cm3/service/cm3_client && _motd_append "restarted cm3_client" ;;
    all ) _cms_restart client; _cms_restart sync ;;
    * ) echo "optional argument must be sync, client, all"; return 1 ;;
  esac
}

_cm3_status () {
  sudo /var/cm3/bin/svstat /var/cm3/service/*
  sudo ls -Ll /var/cm3/logs/cm3_client{,_sync}.log
}

_cm3_log () {
  local log="$1"; shift
  case "${log}" in
    "" | all ) 
               ( sudo cat /var/cm3/logs/cm3_client.log /var/cm3/logs/cm3_client_sync.log ) \
               | sort \
               | /var/cm3/bin/tai64nlocal ;;
    client ) sudo cat /var/cm3/logs/cm3_client.log | /var/cm3/bin/tai64nlocal ;;
    sync ) sudo cat /var/cm3/logs/cm3_client_sync.log | /var/cm3/bin/tai64nlocal ;;
    * ) echo "usage: cm3 log [all|client|sync]" ;;
  esac
}

resource -v -i "$( cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"/"$(basename "${BASH_SOURCE[0]}")" bash_functions

unset DEFAULT_TEMP_DIR DEFAULT_SSH_AUTH_SOCK ALT_SSH_AUTH_SOCK DEFAULT_SSH_AGENT_FILE

