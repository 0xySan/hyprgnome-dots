#!/bin/bash

ENV_FILE="/home/$USER/.config/hyprgnome/.env"

if [[ -f "$ENV_FILE" ]]; then
  # Load variables in a safe way: ignore comments and blank lines
  set -a  # export all variables
  source "$ENV_FILE"
  set +a
else
  echo "⚠️ $ENV_FILE not found. No environment variables loaded."
fi
