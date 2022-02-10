#!/usr/bin/env bash

if [ -f "/diagServer/DiagServer" ]; then
    RESULT2=`pgrep DiagServer`
    if [ "${RESULT2:-null}" = null ]; then
        echo "DiagServer not running, starting again..."
        (cd /diagServer && ./DiagServer --urls "http://0.0.0.0:50055" > /dev/null 2>&1) &
    fi
fi
