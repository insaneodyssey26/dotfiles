#!/bin/bash
if pkill -x wvkbd-mobintl; then
    exit 0
fi
wvkbd-mobintl -L 250 >/dev/null 2>&1 &
disown
