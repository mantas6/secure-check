#!/usr/bin/env bash

# Arguments
server_address=""
healthcheck_url=""
ssh_port=""

status=0


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

options=$(getopt -l "host:,assert-ssh:,assert-url:,assert-port-open:,assert-port-closed:" -o "h:s:c:p:w:" -a -- "$@")
eval set -- "$options"

while true
do
    case $1 in
        -h|--host) 
            shift
            server_address=$1
            ;;
        -s|--assert-ssh)
            shift
            assert_port_open "$1"
            assert_ssh "$server_address" "$1"
            ;;
        -c|--assert-url)
            shift
            assert_url_status "$server_address$1"
            ;;
        -p|--assert-port-open)
            shift
            assert_port_open "$1"
            ;;
        -w|--assert-port-closed)
            shift
            assert_port_closed "$1"
            ;;
        --)
            shift
            break;;
    esac
    shift
done


if [ -z "$server_address" ]; then
    echo "Error: Server address is not provided" >&2
    exit 1
fi

if [ "$status" -eq 0 ]; then
    echo "All checks are successful"
else
    echo "Some checks have failed" >&2
fi

exit "$status"
