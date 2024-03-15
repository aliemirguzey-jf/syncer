#!/bin/bash

### CONSTANTS ###
CONFIG_FILE="$HOME/.config/syncer"
# ANSI escape codes for text colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[34m'
MAGENTA='\033[35m'
NC='\033[0m' # No Color

### FUNCTIONS ###
function traverse_and_sync() {
	local root_folder=$(cat $CONFIG_FILE | grep folder | cut -d'=' -f2)
	local developer=$(cat $CONFIG_FILE | grep developer | cut -d'=' -f2)

	echo -e "Dev:$developer\nFolder:$root_folder\nConfigure at $CONFIG_FILE\n"

	# Check if the root folder exists
	if [ ! -d "$root_folder" ]; then
		echo -e "${RED}Root folder not found:${NC} $root_folder"
		exit 1
	fi

	# Traverse each folder inside the root folder
	for folder in "$root_folder"/*; do
		if [ -d "$folder" ] && [ -d "$folder/.git" ]; then
			(
				cd "$folder" || exit 1
				folder_name=$(basename "$folder")
				echo -e "${YELLOW}[SYNCER] ${MAGENTA}$folder_name${NC}"
				# Get the default Git branch
				default_branch=$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')
				current_branch=$(git branch --show-current)
				status=$(git status -s) 
				if [ -n "$status" ]; then
					echo -e "${YELLOW}[SYNCER]${NC} There are local changes on the branch: Stashing changes" 
					git stash
				fi 
        
				# Checkout the default Git branch
				git checkout "$default_branch" >/dev/null

				# Sync repo if fork
				git config --get remote.origin.url | grep $developer >/dev/null
				if [ $? -eq 0 ]; then
					echo -e "${YELLOW}[SYNCER]${NC} Syncing fork repo to upstream"
					gh repo sync $developer/$folder_name
				fi

				# Pull changes from the remote repository and wait for completion
				git pull >/dev/null
				# Check if 'sync' script exists, and execute it if found
				if [ -f "sync" ]; then
					echo -e "${YELLOW}[SYNCER]${NC} Executing ${BLUE}sync${NC}"
					./sync >/dev/null

					echo -e "${GREEN}[SYNCER]${NC} Done executing ${BLUE}sync${NC}"
				else
					# Execute 'syncAll' script if 'sync' script is not found
					if [ -f "syncAll" ]; then
						echo -e "${YELLOW}[SYNCER]${NC} Executing ${BLUE}syncAll${NC}"
						./syncAll >/dev/null
						echo -e "${GREEN}[SYNCER]${NC} Done executing ${BLUE}syncAll${NC}"
					else
						echo -e "${RED}[SYNCER]${NC} No ${BLUE}sync${NC} or ${BLUE}syncAll${NC} script found in: $folder_name"
					fi
				fi

				if [ -n "$status" ]; then
					git checkout "$current_branch"
					output=$(git stash apply)
					if [[ $output == *"<<<<<<<"* ]]; then
						echo -e "${RED}[SYNCER]${NC} Cannot apply the stash: Conflicts occured"
					else
						echo -e "${GREEN}[SYNCER]${NC} Applied stash successfully."
					fi
				fi 

				echo -e "\n"
			)
		fi
	done
}

# Call the function to start traversing and syncing
traverse_and_sync
