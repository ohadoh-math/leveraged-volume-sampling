#!/usr/bin/env bash

set -eu

function perror()
{
    echo "${BASH_SOURCE[0]}: error: ${@}" >&2
    exit 1
}

function trace()
{
    echo "${@}" >&2
}

readonly INFO_PREFIX=$(echo -ne '\033[0;33minfo\033[0m')
function info_trace()
{
    trace "${INFO_PREFIX}: ${@}"
}

readonly ERROR_PREFIX=$(echo -ne '\033[0;31merror\033[0m')
function error_trace()
{
    trace "${ERROR_PREFIX}: ${@}"
}

function help()
{
    echo "
        usage: ${BASH_SOURCE[0]} [-h] [-x]

        Installs GNU Octave via flatpak package manager on Ubuntu.
        | * -h - print this help.
        | * -x - enable bash's -x flag.
    " | sed -r 's/^\s*\|?//g'
}

while getopts ":hx" option
do
    case "${option}" in
        h)  help
            exit 0
            ;;

        x)  set -x
            ;;

        \?) perror "invalid option -${option} - use -h for help."
            ;;
    esac
done
shift $((OPTIND-1))

info_trace "checking for Ubuntu 16.xx"
if ! which lsb_release &>/dev/null || ! lsb_release -a | grep -qi "Ubuntu 16."
then
    perror "This system doesn't seem to be an Ubuntu 16 distribution (couldn't find lsb_release or the destributor is not Ubuntu)."
fi

info_trace "trying to install flatpak"
if ! sudo apt install flatpak
then
    info_trace "couldn't install flatpak - adding flatpak PPA and retrying"
    sudo add-apt-repository ppa:alexlarsson/flatpak
    sudo apt update
    sudo apt install flatpak
fi

flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

info_trace "flatpak successfully installed - installing GNU Octave"
flatpak install flathub org.octave.Octave

info_trace "flatpak installed"

