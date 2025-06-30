#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="$SCRIPT_DIR:$PATH"

if ! command -v fzf >/dev/null 2>&1; then
	echo "fzf not found, installing..."
	TEMP_DIR=$(mktemp -d)
	git clone --depth 1 https://github.com/junegunn/fzf.git "$TEMP_DIR/.fzf"
	"$TEMP_DIR/.fzf/install" --all
	mv "$TEMP_DIR/.fzf/bin/fzf" "$SCRIPT_DIR/fzf"
	rm -rf "$TEMP_DIR/.fzf"
	echo "fzf installed."
else
	echo "fzf already installed."
fi

fzf="$SCRIPT_DIR/fzf"

GUM_PATH="$SCRIPT_DIR/gum"

# Detect OS and ARCH in proper GitHub release naming format
UNAME_OS=$(uname)
UNAME_ARCH=$(uname -m)

if [[ "$UNAME_OS" == "Linux" ]]; then
	OS="Linux"
elif [[ "$UNAME_OS" == "Darwin" ]]; then
	OS="Darwin"
else
	echo "Unsupported OS: $UNAME_OS"
	exit 1
fi

if [[ "$UNAME_ARCH" == "x86_64" ]]; then
	ARCH="x86_64"
elif [[ "$UNAME_ARCH" == "arm64" || "$UNAME_ARCH" == "aarch64" ]]; then
	ARCH="arm64"
else
	echo "Unsupported architecture: $UNAME_ARCH"
	exit 1
fi

# Only download if not already present
if [ ! -f "$GUM_PATH" ]; then
	echo "Fetching latest gum release info..."

	API_URL="https://api.github.com/repos/charmbracelet/gum/releases/latest"

	DOWNLOAD_URL=$(curl -s "$API_URL" \
	| grep "browser_download_url" \
	| grep "gum_.*_${OS}_${ARCH}\.tar\.gz" \
	| grep -v ".sbom" \
	| cut -d '"' -f 4)

	if [ -z "$DOWNLOAD_URL" ]; then
		echo "Could not find gum binary for ${OS}-${ARCH}"
		exit 1
	fi

	echo "Downloading gum from: $DOWNLOAD_URL"

	TEMP_DIR=$(mktemp -d)
	curl -L "$DOWNLOAD_URL" -o "$TEMP_DIR/gum.tar.gz"

	if file "$TEMP_DIR/gum.tar.gz" | grep -q "gzip compressed data"; then
		tar -xzf "$TEMP_DIR/gum.tar.gz" -C "$TEMP_DIR"

		# Find the actual gum binary inside the extracted directory
		FOUND_GUM=$(find "$TEMP_DIR" -type f -name gum | head -n 1)

		if [[ -z "$FOUND_GUM" || ! -f "$FOUND_GUM" ]]; then
			echo "Failed to locate 'gum' binary in extracted archive."
			exit 1
		fi

		mv "$FOUND_GUM" "$GUM_PATH"
	else
		echo "Downloaded file is not a valid tar.gz:"
		cat "$TEMP_DIR/gum.tar.gz"
		rm -rf "$TEMP_DIR"
		exit 1
	fi
fi

clear

# Use gum for CLI menu
choose_one() {
	local height="$1"
	local header="$2"
	shift 2
	local options=("$@")
	printf '%s\n' "${options[@]}" | $fzf --header="$header" --height="$height" --border --ansi --prompt="> " --no-multi --cycle
}

# Function to select multiple options using fzf
choose_multi() {
	local header="$2"
	shift
	local options=("$@")
	printf '%s\n' "${options[@]}" | $fzf --header="$header" --height=10 --border --ansi --prompt="> " --multi --cycle
}

CHOICE=$(choose_one 10 "Choose what you wanna do today !
Press <Escape> to cancel at any time !" Install Uninstall Update Exit)

case "$CHOICE" in
	Install)
		while true; do
			OPTIONS=$(./gum choose --no-limit --header="Select components:" Kitty Rofi Zen Btop++ Vencord)

			if [[ ! -z "$OPTIONS" ]]; then
				clear
				echo
				tput bold; tput setaf 6
				echo "┏━━━━━━━━━━━━━━━━━━━━━━━┓"
				echo "┃     You selected:     ┃"
				echo "┗━━━━━━━━━━━━━━━━━━━━━━━┛"
				tput sgr0

				# Stylized list of selections
				while IFS= read -r item; do
					tput setaf 2  # green
					printf "  ✔ %s\n" "$item"
				done <<< "$OPTIONS"
				tput sgr0
				echo
			else
				clear
				tput bold; tput setaf 6
				echo "No components selected."
				tput sgr0
			fi

			CONFIRM=$(choose_one 7 "Is this correct?" Yes No)

			if [[ "$CONFIRM" == "Yes" ]]; then
				break
			fi
			clear
			echo "Let's try again..."
		done

		clear
		if [[ ! -z "$OPTIONS" ]]; then
			clear
			echo
			tput bold; tput setaf 6
			echo "┏━━━━━━━━━━━━━━━━━━━━━━━┓"
			echo "┃     You selected:     ┃"
			echo "┗━━━━━━━━━━━━━━━━━━━━━━━┛"
			tput sgr0

			# Stylized list of selections
			while IFS= read -r item; do
				tput setaf 2  # green
				printf "  ✔ %s\n" "$item"
			done <<< "$OPTIONS"
			tput sgr0
			echo
		else
			clear
			tput bold; tput setaf 6
			echo "No components selected."
			tput sgr0
		fi

		CHOICE_DIR=$(choose_one 11 "Where would you like to install it?
Careful ! 
Only give full paths and do not use link symbols,
as it could break the install for custom locations !" "$HOME/.local/share/hyprgnome" "$HOME/hyprgnome" "Custom location")

		if [[ "$CHOICE_DIR" == "Custom location" ]]; then
			read -rp "Enter custom install path: " INSTALL_PATH
		else
			INSTALL_PATH="$CHOICE_DIR"
		fi
		

		OWNER=$(namei -l "$CHOICE_DIR" | tail -n 2 | head -n 1 | awk '{print $2}')
		ME=$(whoami)

		if [ "$OWNER" != "$ME" ]; then
			echo "You are not the owner of the sub directory you chose. Hence you cannot create this directory."
			exit 1
		fi
	
		if [ ! -d "$INSTALL_PATH" ]; then
			CREATE=$(choose_one 7 "Directory does not exist. Create it?" Yes No)
			if [[ "$CREATE" == "Yes" ]]; then
				mkdir -p "$INSTALL_PATH"
				echo "Directory created."
			else
				echo "Installation aborted."
				exit 1
			fi
		fi

		# Your actual install commands here
		echo "Installing files to $INSTALL_PATH..."
		git clone https://github.com/Homebrew/brew $INSTALL_PATH/homebrew
		eval "$($INSTALL_PATH/homebrew/bin/brew shellenv)"
		brew update --force --quiet
		chmod -R go-w "$(brew --prefix)/share/zsh"

		CONFIRM=$(choose_one 7 "Wanna add Homebrew in your .zshrc ?" Yes No)
		
		if [[ "$CONFIRM" == "Yes" ]]; then
			echo "Adding Homebrew to your .zshrc..."
			echo "export PATH=\"$INSTALL_PATH/homebrew/bin:\$PATH\"" >> "$HOME/.zshrc"
			echo "Homebrew added to .zshrc."
		else
			echo "Homebrew not added to .zshrc."
		fi
		;;
	Uninstall)
		echo "Uninstalling..."
		;;
	Update)
		echo "Updating..."
		;;
	Exit)
		echo "Goodbye!"
		;;
	*)
		echo "Invalid choice."
		;;
esac
