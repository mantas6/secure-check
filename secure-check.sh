#!/usr/bin/env bash

server_address=$1

status=0

set_failure_status() {
    status=1
}

check_closed_port() {
    echo "Checking port $1"
    # TODO: handle timeout
    return $(timeout 5 telnet "$server_address" $1 < /dev/null 2>&1 | grep -q "Connection refused")
}

assert_port_closed() {
    if ! check_closed_port $1; then
        set_failure_status
        echo "Assertion failed: port $1 must be closed" >&2
    fi
}

assert_port_open() {
    if check_closed_port $1; then
        set_failure_status
        echo "Assertion failed: port $1 must be closed" >&2
    fi
}

if [ -z "$server_address" ]; then
    echo "Error: Server address is not provided" >&2
    exit 1
fi

echo "Running checks on $server_address"

http_status=$(curl -s -o /dev/null -w "%{http_code}" --max-redirs 5 -L "$server_address")
echo "HTTP status is $http_status"

if [[ "$http_status" -ne 200 ]]; then
    echo "Assertion failed: unsuccessful HTTP status $http_status" >&2
    set_failure_status
fi

# TODO: ports in env file

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
