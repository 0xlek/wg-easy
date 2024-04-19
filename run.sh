#!/bin/bash

while true; do
    /usr/bin/portfwd
    echo "portfwd 1 exited. Restarting..."
    sleep 1
done &

node server.js
