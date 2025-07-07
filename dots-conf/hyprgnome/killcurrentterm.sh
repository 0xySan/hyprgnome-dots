#!/bin/bash

export $(grep -v '^#' /home/$USER/.config/hyprgnome/.env | xargs)

REAL_PID=$($CONF/hyprgnome/window_pid)

echo "REAL_PID: $REAL_PID"

kill -9 "$REAL_PID"