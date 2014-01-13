#!/bin/bash

## DESCRIPTION: Given a source directory and a Riak source directory,
##              moves beam files around for more rapid development

## AUTHOR: Drew Kerrigan

declare -r SCRIPT_NAME=$(basename "$BASH_SOURCE" .sh)

## exit the shell(default status code: 1) after printing the message to stderr
bail() {
    echo -ne "$1" >&2
    exit ${2-1}
}

## help message
declare -r HELP_MSG="
Given a source directory and a Riak source directory, moves beam files around for more rapid development

Pre-Requisites: run 'make rel' on riak first using the appropriate branch

Partial Example: ./bin/$SCRIPT_NAME.sh -m partial -r ~/src/basho/riak/ -j ~/src/basho/riak_mongo/
Partial Example Without Deps: ./bin/$SCRIPT_NAME.sh -m partial -r ~/src/basho/riak/ -j ~/src/basho/riak_mongo/ -s
Full Example: ./bin/$SCRIPT_NAME.sh -m full -r ~/src/basho/riak/ -j ~/src/basho/riak_mongo/

Usage: $SCRIPT_NAME [OPTION]... [ARG]...
  -m    mode [full (make rel on riak) | partial (in place copy of rj ebin)]
  -c    will run make clean on riak mongo
  -r    riak source directory
  -j    riak_mongo source directory
  -s    skip dependencies
"

## print the usage and exit the shell(default status code: 2)
usage() {
    declare status=2
    if [[ "$1" =~ ^[0-9]+$ ]]; then
        status=$1
        shift
    fi
    bail "${1}$HELP_MSG" $status
}

mode=partial

while getopts ":m:c:r:j:s" opt; do
    case $opt in
        m)
            mode=${OPTARG}
            ;;
        c)
            clean="true"
            ;;
        r)
            riak_path=${OPTARG}
            ;;
        j)
            source_path=${OPTARG}
            ;;
        s)
            skipdeps="true"
            ;;
        *)
            usage 0
            ;;
    esac
done

#==========MAIN CODE BELOW==========

if [ "${mode}" != 'full' ]; then
    echo "Partial Mode"
    if [ "${clean}" == 'true' ]; then
        echo "Running make clean on $source_path"
        cd ${source_path} && make clean
    fi
    echo "Running make on $source_path"
    if [ "${skipdeps}" == 'true' ]; then
        cd ${source_path} && ./rebar compile skip_deps=true
    else
        cd ${source_path} && make
    fi
    echo "Cleaning ebin.."
    rm ${riak_path}rel/riak/lib/riak_mongo-1/ebin/*
    echo "Copying new ebin"
    cp -R ${source_path}ebin/* ${riak_path}rel/riak/lib/riak_mongo-1/ebin/
    echo "Fixing riak.conf"
    cp ${riak_path}rel/riak/etc/riak.conf ${riak_path}rel/riak/etc/riak.conf.bak
    sed 's/search = off/search = on/g' ${riak_path}rel/riak/etc/riak.conf.bak > ${riak_path}rel/riak/etc/riak.conf
    if [ $(grep "buckets.default.siblings" ${riak_path}/rel/riak/etc/riak.conf | wc -l) -eq 0 ];
        then echo "buckets.default.siblings = off" >> ${riak_path}rel/riak/etc/riak.conf;
    fi
    echo "Stopping Riak"
    bash ${riak_path}rel/riak/bin/riak stop
    ulimit -n 4096
    echo "Starting Riak"
    bash ${riak_path}rel/riak/bin/riak start
else
    echo "Full Mode"
    echo "Cleaning dependency"
    rm -rf ${riak_path}deps/riak_mongo/
    if [ "${clean}" == 'true' ]; then
        echo "Running make clean on $source_path"
        cd ${json_path} && make clean
    fi
    echo "Copying dependency"
    cp -R ${source_path} ${riak_path}deps/riak_mongo
    echo "Cleaning rel"
    cd ${riak_path} && make relclean
    echo "Making rel"
    cd ${riak_path} && make rel
    echo "Fixing riak.conf"
    cp ${riak_path}rel/riak/etc/riak.conf ${riak_path}rel/riak/etc/riak.conf.bak
    sed 's/search = off/search = on/g' ${riak_path}rel/riak/etc/riak.conf.bak > ${riak_path}rel/riak/etc/riak.conf
    if [ $(grep "buckets.default.siblings" ${riak_path}/rel/riak/etc/riak.conf | wc -l) -eq 0 ];
        then echo "buckets.default.siblings = off" >> ${riak_path}rel/riak/etc/riak.conf;
    fi
    echo "Stopping Riak"
    bash ${riak_path}rel/riak/bin/riak stop
    ulimit -n 4096
    echo "Starting Riak"
    bash ${riak_path}rel/riak/bin/riak start
fi

cd ${source_path}
