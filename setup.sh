#!/usr/bin/env bash

set -eu

# This script performs environment setup.
# It fetches the required data sets as configured in the datasets file
# and places them in the .data/ directory.

readonly PROJECT_BASE=$(dirname $(readlink -f "${BASH_SOURCE[0]}"))
readonly SCRIPT=$(basename "${BASH_SOURCE[0]}")

readonly DEFAULT_DATASETS_FILE="${PROJECT_BASE}/datasets"
readonly DEFAULT_DATASETS_DIR="${PROJECT_BASE}/.data/"
readonly DEFAULT_DATASETS_CACHE="${PROJECT_BASE}/.datasets-cache"

function perror()
{
    echo "${SCRIPT}: error: ${@}" >&2
    exit 1
}

function trace()
{
    echo "${@}" >&2
}

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
    " | sed -r 's/^\s*|?//g'
}

datasets_dir="${DEFAULT_DATASETS_DIR}"
datasets_list="${DEFAULT_DATASETS_FILE}"
datasets_cache="${DEFAULT_DATASETS_CACHE}"

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

# create output directory
mkdir -p "${datasets_dir}"

# download datasets
while read dataset_url
do
    # make sure that we have the proper decompressor if decompression is needed
    if echo "${dataset_url}" | grep -qiP '\.bz2$' && ! which bzip2 &>/dev/null
    then
        trace "error: can't find bzip2 decompressor - skipping ${dataset_url}"
    fi

    # extract file name from URL by treating it as a UNIX path
    dataset_file="${datasets_dir}/"$(basename "${dataset_url}")
    trace "fetching ${dataset_url} to ${dataset_file}..."
    if ! curl -o "${dataset_file}" "${dataset_url}"
    then
        trace "    error: couldn't fetch ${dataset_url}"
        rm -f "${dataset_file}"
        continue
    fi

    # check if decompression is required
    if echo "${dataset_file}" | grep -qiP '\.bz2$'
    then
        trace "    decompressing ${dataset_file}..."
        bzip2 -d "${dataset_file}"
        dataset_file=$(echo "${dataset_file}" | sed -r 's/\.bz2$//gi')
        trace "        -> decompressed to ${dataset_file}"
    fi

    # remove column indicator notation from the datasets as these seem to confuse GNU Octave.
    trace "    removing column indicators from ${dataset_file}..."
    sed -i -r 's/[0-9]+://g' "${dataset_file}"

    # write dataset to cache file
    trace "    adding ${dataset_file} to cache file ${datasets_cache}"
    dataset_hash=$(sha1sum "${dataset_file}" | cut -d' ' -f1)
    echo "${dataset_url} ${dataset_file} ${dataset_hash}" >> ${datasets_cache}

done < ${datasets_list}

