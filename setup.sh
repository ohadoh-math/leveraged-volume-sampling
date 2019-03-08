#!/usr/bin/env bash

set -eu

# This script performs environment setup.
# It fetches the required data sets as configured in the datasets file
# and places them in the downloaded-datasets/ directory.
# After that, the format is normalized for Octave usage.

readonly PROJECT_BASE=$(dirname $(readlink -f "${BASH_SOURCE[0]}"))
readonly SCRIPT=$(basename "${BASH_SOURCE[0]}")

readonly SOURCE_DIR="${PROJECT_BASE}/src"
readonly SQUARE_FEATURES_SCRIPT="${SOURCE_DIR}/square-features.m"

readonly DEFAULT_DATASETS_FILE="${PROJECT_BASE}/datasets-config"
readonly DEFAULT_DATASETS_DIR="${PROJECT_BASE}/downloaded-datasets/"
readonly DEFAULT_DATASETS_CACHE="${PROJECT_BASE}/datasets-cache"

readonly CACHE_FIELD_SEPARATOR="$(echo -ne '\t')"

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

# Cache utilities

function print_dataset_config()
{
    _cache_file="${1}"
    sed -r '
        # drop comments
        /^\s*#/ d

        # drop empty lines
        /^\s*$/ d
    ' "${_cache_file}"
}

# check if dataset is listed and valid
function is_dataset_cached()
{
    local _cache_file="${1}"
    local _dataset_url="${2}"

    # check if the dataset url is in the cache.
    if ! print_dataset_config "${_cache_file}" | grep -qF "${_dataset_url}"
    then
        # it isn't
        return 1
    fi

    # read the cached file path and hash from the cache
    IFS="${CACHE_FIELD_SEPARATOR}" read _cached_url _cached_path _cached_hash _sampling_count < <(print_dataset_config "${_cache_file}" | grep -F "${_dataset_url}" | head -1)

    # if the file doesn't exist remove the cache line and fail
    if ! [ -f "${_cached_path}" ]
    then
        sed -i "/${_cached_hash}/ d" "${_cache_file}"
        return 1
    fi

    # if the hash doesn't match, do the same
    local _calculated_hash=$(sha1sum "${_cached_path}" | cut -d' ' -f1)
    if [ "${_cached_hash}" != "${_calculated_hash}" ]
    then
        sed -i "/${_cached_hash}/ d" "${_cache_file}"
        return 1
    fi

    # file is in cache
    return 0
}

# add an entry to the cache file
function write_cache_line()
{
    local _cache_file="${1}"
    local _dataset_url="${2}"
    local _file="${3}"
    local _hash="${4}"
    local _sampling_count="${5}"

    echo "${_dataset_url}${CACHE_FIELD_SEPARATOR}${_file}${CACHE_FIELD_SEPARATOR}${_hash}${CACHE_FIELD_SEPARATOR}${_sampling_count}" >> ${_cache_file}
}

# copy a cached file to the output directory and update the cache with the correct path
function update_cached_file()
{
    local _cache_file="${1}"
    local _dataset_url="${2}"
    local _output_directory="${3}"

    local _output_file="${_output_directory}/"$(basename "${_dataset_url}" | awk -F/ '{print $NF}' | sed -r 's/\.[^.]+$//g')
    _output_file=$(readlink -f "${_output_file}")

    # read the cached file path and hash from the cache
    IFS="${CACHE_FIELD_SEPARATOR}" read _cached_url _cached_path _cached_hash _sampling_count < <(print_dataset_config "${_cache_file}" | grep -F "${_dataset_url}" | head -1)
    cached_path=$(readlink -f "${_cached_path}")

    # check if the output file is the cached file
    if [ "${_cached_path}" == "${_output_file}" ]
    then
        # nothing to do
        return 0
    fi

    cp "${_cached_file}" "${_output_file}"

    write_cache_line "${_cache_file}" "${_dataset_url}" "${_output_file}" "${_cached_hash}" "${_sampling_count}"
}

# octave detection functions
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

function detect_octave()
{
    # check the path for octave
    if [ -z "${FORCE_FLATPAK:-}" ] && which "octave-cli" &> /dev/null
    then
        use_flatpak_octave="0"
        return 0;
    fi

    # the path doesn't hold a good enough octave.
    # check flatpak.
    if which flatpak &>/dev/null && flatpak list | grep -qiw Octave
    then
        use_flatpak_octave="1"
        return 0;
    fi

    use_flatpak_octave=""
    return 1
}

# download a dataset file
function fetch_dataset()
{
    local _cache_file="${1}"
    local _dataset_url="${2}"
    local _output_directory="${3}"
    local _sampling_count="${4}"
    local _square_features="${5}"

    local _output_file="${_output_directory}/"$(basename "${_dataset_url}" | awk -F/ '{print $NF}')
    _output_file=$(readlink -f "${_output_file}")

    # try at 3 times because some-times there's a connectivity error
    curl -o "${_output_file}" "${_dataset_url}" || \
    curl -o "${_output_file}" "${_dataset_url}" || \
    curl -o "${_output_file}" "${_dataset_url}"

    # if the output file is compressed with bzip2 then decompress it
    if echo "${_output_file}" | grep -qP '\.bz2$'
    then
        local _compressed_file="${_output_file}"
        _output_file=$(echo "${_output_file}" | sed -r 's/\.bz2$//')
        rm -f "${_output_file}"
        bzip2 -d "${_compressed_file}"
    fi

    # now remove the 'column:' notation in the dataset
    sed -i -r 's/[0-9]+://g' "${_output_file}"

    # check if the configuration says we need to add square features columns
    if [ "true" == "${_square_features}" ]
    then
        info_trace "squaring features for ${_output_file}"
        run_octave -p "${SOURCE_DIR}" "${SQUARE_FEATURES_SCRIPT}" "${_output_file}"
    fi

    # and add the file to the cache
    _hash=$(sha1sum "${_output_file}" | cut -d' ' -f1)
    write_cache_line "${_cache_file}" "${_dataset_url}" "${_output_file}" "${_hash}" "${_sampling_count}"
}

# Main
function help()
{
    echo "
        usage: ${SCRIPT} [-h] [-x] [-s DATASETS-FILE] [-c DATASETS-CACHE-FILE] [-o OUTPUT-DIRECTORY]

        Performs basic setup of the execution environment.
        Fetches datasets listed in a dataset configuration file.
        | * -h - print this help.
        | * -x - enable bash's -x flag.
        | * -s DATASET-FILE - use the configuration listed in DATASET-FILE (default: ${DEFAULT_DATASETS_FILE}).
        | * -c DATASETS-CACHE-FILE - use DATASETS-CACHE-FILE to store the hashes of the downloaded data sets (default: ${DEFAULT_DATASETS_CACHE}).
        | * -o OUTPUT-DIRECTORY - use OUTPUT-DIRECTORY to store the data sets (default: ${DEFAULT_DATASETS_DIR}).
    " | sed -r 's/^\s*\|?//g'
}

datasets_dir="${DEFAULT_DATASETS_DIR}"
datasets_list="${DEFAULT_DATASETS_FILE}"
datasets_cache="${DEFAULT_DATASETS_CACHE}"

# first, detect GNU Octave
detect_octave || perror "couldn't detect Octave. try using ./install-flatpak-octave.sh"

while getopts ":hxs:c:o:" option
do
    case "${option}" in
        h)  help
            exit 0
            ;;

        x)  set -x
            ;;

        s)  datasets_list=$(readlink -f "${OPTARG}")
            ;;

        c)  datasets_cache=$(readlink -f "${OPTARG}")
            ;;

        o)  datasets_dir=$(readlink -f "${OPTARG}")
            ;;

        \?) perror "invalid option -${option} - use -h for help."
            ;;
    esac
done

# create output directory and cache file
mkdir -p "${datasets_dir}"
touch "${datasets_cache}"

# download the datasets
print_dataset_config "${datasets_list}" | while read dataset_url square_features sampling_count
do
    info_trace "checking dataset: ${dataset_url}..."
    if is_dataset_cached "${datasets_cache}" "${dataset_url}"
    then
        info_trace "    dataset already exists in cache!"
        update_cached_file "${datasets_cache}" "${dataset_url}" "${datasets_dir}"
    else
        info_trace "    downloading the dataset..."
        fetch_dataset "${datasets_cache}" "${dataset_url}" "${datasets_dir}" "${sampling_count}" "${square_features}"
        info_trace "    downloaded ${dataset_url}"
    fi
done

info_trace "done!"

