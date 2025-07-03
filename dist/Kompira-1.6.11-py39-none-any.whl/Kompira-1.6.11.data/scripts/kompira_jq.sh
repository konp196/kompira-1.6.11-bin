#! /bin/bash

function usage {
    cat <<EOF
usage: kompira_jq.sh [options] uri [query...]
  --server SERVER     URL of the kompira server
  --token TOKEN       Kompira authorization TOKEN
  --jq QUERY          Query string for jq
  --active            active objects
  --count             count objects
  --verbose
EOF
    exit 1
}

verbose=
curl_opts="-Ssk4"
uri_query=
jq_opts="-r"
jq_query=
active_query="is_active=True"
count_query="page_size=1&attrs="
count_jq=".count"

if [ -f ~/.kompirarc ]; then
    . ~/.kompirarc
fi

opts=$(getopt -q -o 's:t:j:acv' -l 'server:,token:,jq:,active,count,verbose' -- "$@")
if [ $? != 0 ]; then
    usage
fi
eval set -- "$opts"

while true
do
    case "$1" in
        -s | --server)  server=$2; shift;;
        -t | --token)   token=$2; shift;;
        -j | --jq)      jq_query=$2; shift;;
        -a | --active)  uri_query="$uri_query&$active_query";;
        -c | --count)   uri_query="$uri_query&$count_query"; jq_query=$count_jq;;
        -v | --verbose) verbose=1;;
        --) shift; break;;
        *) usage;;
    esac
    shift
done

if [ -z "$token" ]; then
    echo "ERROR: token is not specified"
    exit 1
fi

if [ -z "$server" ]; then
    echo "ERROR: server is not specified"
    exit 1
fi
server=$(echo "$server" | sed -re 's|/*$||')

uri="$1"
shift
if [ -z "$uri" ]; then
    echo "ERROR: uri is not specified"
    exit 1
fi

while [ -n "$1" ]; do
    uri_query="$uri_query&$1"
    shift
done
if [ -n "$uri_query" ]; then
    uri_query=$(echo "$uri_query" | sed -re 's/^&//')
    if [[ "$uri" == *\?* ]]; then
        uri="$uri&$uri_query"
    else
        uri="$uri?$uri_query"
    fi
fi
uri=$(echo "$uri" | sed -re 's|^/*||')
url="$server/$uri"

[ -n "$verbose" ] && echo "URL: $url" > /dev/stderr
curl $curl_opts -H "Accept: application/json" -H "Authorization: Token $token" "$url" | (
    if [ -n "$jq_query" ]; then
        jq $jq_opts "$jq_query"
    else
        cat
    fi
)
exit $PIPESTATUS
