#!/usr/bin/env bash

# Arguments
server_address=""
healthcheck_url=""
ssh_port=""

status=0

while getopts ":h:s:a:" opt; do
  case $opt in
    h) healthcheck_url="$OPTARG";;
    s) ssh_port="$OPTARG";;
    a) server_address="$OPTARG";;
    \?) echo "Invalid option -$OPTARG" >&2; exit 1;;
  esac
done

set_failure_status() {
    status=1
}

check_closed_port() {
    echo "Checking port $1"
    nc -z -w5 "$server_address" "$1"
}

check_url_status() {
    http_status=$(curl -s -o /dev/null -w "%{http_code}" --max-redirs 5 -L "$1")

    echo "HTTP status $1 $http_status"

    if [[ "$http_status" -eq 200 ]]; then
        return 0
    else
        return 1
    fi
}

assert_port_closed() {
    check_closed_port "$1"

    if [ $? -eq 0 ]; then
        set_failure_status
        echo "Assertion failed: port $1 must be closed" >&2
    fi
}

assert_port_open() {
    check_closed_port "$1"

    if [ $? -ne 0 ]; then
        set_failure_status
        echo "Assertion failed: port $1 must be closed" >&2
    fi
}

assert_url_status() {
    check_url_status "$1"

    if [[ $? -ne 0 ]]; then
        echo "Assertion failed: unsuccessful $1 status $http_status" >&2
        set_failure_status
    fi
}

assert_ssh() {
    ssh_result=$(timeout 5 ssh "$1" -p "$2" \
        -o LogLevel=ERROR \
        -o PubkeyAuthentication=no \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null 2>&1)

    if [[ "$ssh_result" =~ "Permission denied" ]]; then
        echo "SSH OK $ssh_result"
    else
        set_failure_status
        echo "SSH attempt assertion failed $ssh_result"
    fi
}

if [ -z "$server_address" ]; then
    echo "Error: Server address is not provided" >&2
    exit 1
fi

echo "Running checks on $server_address"

assert_url_status "$server_address"

if [ -n "$healthcheck_url" ]; then
    assert_url_status "$server_address$healthcheck_url"
fi

if [ -n "$ssh_port" ]; then
    assert_ssh "$server_address" "$ssh_port"
fi

# TODO: ports in env file
#
# SSH
assert_port_closed 22

# Redis
assert_port_closed 6379
# MySQL
assert_port_closed 3306

# Laravel Octane
assert_port_closed 8000

# HTTP/HTTPS
assert_port_open 80
assert_port_open 443

if [ "$status" -eq 0 ]; then
    echo "All checks are successful"
else
    echo "Some checks have failed" >&2
fi

exit "$status"
