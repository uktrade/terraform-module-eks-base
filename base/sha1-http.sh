#!/usr/bin/env bash

function error_exit() {
  echo "$1" 1>&2
  exit 1
}

function check_deps() {
  test -f $(which curl) || error_exit "curl command not detected in path, please install it"
  test -f $(which sha1sum) || error_exit "sha1sum command not detected in path, please install it"
  test -f $(which jq) || error_exit "jq command not detected in path, please install it"
}

function parse_input() {
  eval "$(jq -r '@sh "export URL=\(.url)"')"
  if [[ -z "${URL}" ]]; then error_exit "URL is missing"; fi
}

function sha1() {
  export SHA1=$(curl -Lfs "${URL}" | sha1sum | awk '{print $1}')
}

function output() {
  jq -n --arg sha1 "$SHA1" '{"sha1": $sha1}'
}

# main()
check_deps
parse_input
sha1
output
