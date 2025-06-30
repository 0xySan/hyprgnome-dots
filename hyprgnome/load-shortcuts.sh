#!/bin/bash

echo "🔄 Loading shortcuts from /home/etaquet/.config/hyprgnome/shortcuts.conf"

# Load environment variables
source /home/etaquet/.config/hyprgnome/load-env.sh

CONFIG_FILE="/home/etaquet/.config/hyprgnome/shortcuts.conf"
BASE_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings"
SHORTCUT_PATHS=()
INDEX=0

while IFS= read -r LINE || [ -n "$LINE" ]; do
  LINE=$(echo "$LINE" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  [[ -z "$LINE" || "$LINE" =~ ^# ]] && continue

  NAME=${LINE%%=*}
  REST=${LINE#*=}

  NAME=$(echo "$NAME" | xargs)
  REST=$(echo "$REST" | xargs)

  COMMAND=${REST%%,*}
  BINDING=${REST#*,}

  COMMAND=$(echo "$COMMAND" | xargs)
  BINDING=$(echo "$BINDING" | xargs)

  # Expand env vars in command
  COMMAND=$(echo "$COMMAND" | envsubst)

  SHORTCUT_ID="custom$INDEX"
  SHORTCUT_PATH="$BASE_PATH/$SHORTCUT_ID/"
  SHORTCUT_PATHS+=("'$SHORTCUT_PATH'")

  echo "🔧 Creating shortcut [$NAME] => $COMMAND on $BINDING"

  gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$SHORTCUT_PATH name "$NAME"
  gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$SHORTCUT_PATH command "$COMMAND"
  gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$SHORTCUT_PATH binding "$BINDING"

  ((INDEX++))
done < "$CONFIG_FILE"

JOINED_PATHS=$(IFS=, ; echo "${SHORTCUT_PATHS[*]}")
LIST_STR="[$JOINED_PATHS]"

gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "$LIST_STR"

echo "✅ Loaded $INDEX shortcuts from $CONFIG_FILE"
