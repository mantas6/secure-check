#!/usr/bin/env bash

host="$1"
ssh_port="$2"

./secure-check.sh -h $host \
    --assert-ssh=$ssh_port \
    --assert-url= \
    --assert-url=/api/healthcheck \
    --assert-port-open=80 \
    --assert-port-open=443 \
    --assert-port-closed=6379 \
    --assert-port-closed=3306 \
    --assert-port-closed=8000
