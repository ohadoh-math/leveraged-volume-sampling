#!/usr/bin/env bash

set -eu

export PS4='$(date +"%Y-%m-%d %H:%M:%S") $0.$LINENO+ '

# This script runs the Leveraged Volume Sampling implementation on
# downloaded datasets and generates graphs comparing it to Leverage Score Sampling
# and regular Volume Sampling procedures.
# The output graphs are placed in the graphs/ directory

readonly PROJECT_BASE=$(dirname $(readlink -f "${BASH_SOURCE[0]}"))
readonly SCRIPT=$(basename "${BASH_SOURCE[0]}")

readonly DEFAULT_DATASETS_CACHE="${PROJECT_BASE}/datasets-cache"
readonly DEFAULT_GRAPHS_DIRECTORY="${PROJECT_BASE}/graphs"
readonly SETUP_SCRIPT="${PROJECT_BASE}/setup.sh"

readonly SOURCE_DIR="${PROJECT_BASE}/src"
readonly MAIN_SCRIPT="${SOURCE_DIR}/main.m"

# Logging utilities
function perror()
{
    echo "${SCRIPT}: error: ${@}" >&2
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
        usage: ${SCRIPT} [-h] [-x] [-t] [-o OUTPUT-DIRECTORY] [-c DATASETS-CACHE] [-d DATASETS-DIRECTORY] [-s DATASETS-FILE]

        Runs Leverage Volume Sampling on a given set of datasets and plots it's
        performance vs regular Volume Sampling and Leverage Score Sampling.
        The datasets are fetched using ./setup.sh.
        | * -h - print this help.
        | * -x - enable bash's -x flag.
        | * -t - set TRACE_INFO for extra debug traces.
        | * -o OUTPUT-DIRECTORY - where to write the graphs to.
        | * -c DATASETS-CACHE - the cache file to consult.
        | * -d DATASETS-DIRECTORY - the directory to download the datasets to.
        | * -s DATASETS-FILE - the datasets configuration file.
    " | sed -r 's/^\s*\|?//g'
}

# Octave

use_flatpak_octave=""
function run_octave()
{
    if [ -z "${use_flatpak_octave}" ]
    then
        perror "Octave version was not detected"
    elif [ "${use_flatpak_octave}" == "1" ]
    then
        flatpak run                         \
            --branch=stable                 \
            --arch=x86_64                   \
            --command=/app/bin/octave-cli   \
            --filesystem=host               \
            org.octave.Octave "${@}"
    else
        octave-cli "${@}"
    fi
}

function validate_octave_version()
{
    local _octave_version=$(run_octave --version | awk '/GNU Octave, version/ {print $NF; exit(0);}');

    if awk -v OCTAVE_VER="${_octave_version}" 'BEGIN {
                                                    if (OCTAVE_VER >= "4.4.1") {
                                                        exit(0);
                                                    } else {
                                                        exit(1);
                                                    }
                                                 }'
    then
        return 0
    fi

    info_trace "found an old version of Octave (${_octave_version})"
    return 1
}

function detect_octave()
{
    # check the path for octave
    if [ -z "${FORCE_FLATPAK:-}" ] && which "octave-cli" &> /dev/null
    then
        use_flatpak_octave="0"
        if validate_octave_version
        then
            return 0;
        fi
    fi

    # the path doesn't hold a good enough octave.
    # check flatpak.
    if which flatpak &>/dev/null && flatpak list | grep -qiw Octave
    then
        use_flatpak_octave="1"
        if validate_octave_version
        then
            return 0;
        fi
    fi

    use_flatpak_octave=""
    return 1
}

# Main

cache_file="${DEFAULT_DATASETS_CACHE}"
graphs_directory="${DEFAULT_GRAPHS_DIRECTORY}"

while getopts ":hxto:c:d:s:" option
do
    case "${option}" in
        h)  help
            exit 0
            ;;

        x)  set -x
            setup_x_flag="-x"
            ;;

        t)  export TRACE_INFO="1"
            ;;

        o)  graphs_directory="${OPTARG}"
            ;;

        c)  cache_file="${OPTARG}"
            ;;

        d)  setup_datasets_dir_arg="-o ${OPTARG}"
            ;;

        s)  setup_datasets_config_arg="-s ${OPTARG}"
            ;;

        \?) perror "invalid option -${option} - use -h for help."
            ;;
    esac
done

info_trace "detecting Octave version..."
detect_octave || perror "couldn't detect Octave. try using ./install-flatpak-octave.sh"
info_trace "Octave detected!"

info_trace "fetching datasets..."
${SETUP_SCRIPT} ${setup_x_flag:-} -c "${cache_file}" ${setup_datasets_dir_arg:-} ${setup_datasets_config_arg:-}
info_trace "datasets fetched!"

mkdir -p "${graphs_directory}"

grep -vP '^#' "${cache_file}" | while IFS="$(echo -ne '\t')" read url dataset_file dataset_hash sampling_count
do
    graph_file="${graphs_directory}/$(basename ${dataset_file}).png"
    info_trace "processing ${dataset_file}..."
    run_octave -p "${SOURCE_DIR}" "${MAIN_SCRIPT}" "${dataset_file}" "${graph_file}" "${sampling_count}"
    info_trace "    generated ${graph_file} !"
done

info_trace "done!"

