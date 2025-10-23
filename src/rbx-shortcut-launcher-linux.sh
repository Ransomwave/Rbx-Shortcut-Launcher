#!/bin/bash

#HACK: Using global variables as function arguments is probably not a good idea

# If the user has some custom very weird package manager, that's on them
install_packages() {
  echo "Requesting sudo"

  if command -v apt &>/dev/null; then
    sudo apt install ffmpeg curl jq
  elif command -v yum &>/dev/null; then
    sudo yum install curl jq
    # ffmpeg
    sudo yum install epel-release -y
    sudo yum update
    sudo yum install ffmpeg ffmpeg-devel -y
  elif command -v dnf &>/dev/null; then
    sudo dnf install curl ffmpeg jq
  elif command -v zypper &>/dev/null; then
    sudo zypper refresh
    sudo zypper install curl ffmpeg jq
  elif command -v pacman &>/dev/null; then
    sudo pacman -S curl ffmpeg jq
  else
    echo "Distro not supported, please install ffmpeg and/or curl using your package manager :3"
    exit 1
  fi
  clear
  echo "packages installed"
}

prompt_for_install_packages() {
  echo "No required packages found. Do you want to attempt to install those required packages?"
  read -p "Y/N >>>" prompt
  if [[ "${prompt,,}" == "y" ]]; then
    install_packages
  else
    exit 1
  fi
}

# downloading game 😱
download_game() {
  # we'll be storing icons @ ~/.local/share/icons (user-wide icon folder for .desktop files)

  echo "[1/3] Initiating game image download"
  local iconID=$(curl "https://thumbnails.roblox.com/v1/games/icons?universeIds=${universeID}&returnPolicy=PlaceHolder&size=256x256&format=Png&isCircular=false" | jq ".data[0].imageUrl")
  echo "Got icon URL: ${iconID//\"/}"
  curl "${iconID//\"/}" >temp.png

  echo "[2/3] Resizing images (16x16, 24x24, 32x32, 48x48, 64x64, 96x96, 128x128, 256x256)"

  #NOTE: You probably shouldn't use ffmpeg to convert images, but ImageMagick is a bit more complicated to get, and i cannot be bothered
  #      Also to prevent a weird issue where the icon just doesn't show up, we convert EVERYTHING ALL AT ONCE
  ffmpeg -i temp.png -s 16x16 -hide_banner -loglevel error temp2.png
  ffmpeg -i temp.png -s 24x24 -hide_banner -loglevel error temp3.png
  ffmpeg -i temp.png -s 32x32 -hide_banner -loglevel error temp4.png
  ffmpeg -i temp.png -s 48x48 -hide_banner -loglevel error temp5.png
  ffmpeg -i temp.png -s 64x64 -hide_banner -loglevel error temp6.png
  ffmpeg -i temp.png -s 96x96 -hide_banner -loglevel error temp7.png
  ffmpeg -i temp.png -s 128x128 -hide_banner -loglevel error temp8.png
  # 256x256 is the source image, doing ffmpeg on that is redundant

  echo "[3/3] Putting icons where they belong"
  echo "Requesting sudo access, because we might not be able to access the user icon folder"

  sudo mv "temp.png" "$HOME/.local/share/icons/hicolor/256x256/apps/RBXGAME_${gameID}.png"
  sudo mv "temp2.png" "$HOME/.local/share/icons/hicolor/16x16/apps/RBXGAME_${gameID}.png"
  sudo mv "temp3.png" "$HOME/.local/share/icons/hicolor/24x24/apps/RBXGAME_${gameID}.png"
  sudo mv "temp4.png" "$HOME/.local/share/icons/hicolor/32x32/apps/RBXGAME_${gameID}.png"
  sudo mv "temp5.png" "$HOME/.local/share/icons/hicolor/48x48/apps/RBXGAME_${gameID}.png"
  sudo mv "temp6.png" "$HOME/.local/share/icons/hicolor/64x64/apps/RBXGAME_${gameID}.png"
  sudo mv "temp7.png" "$HOME/.local/share/icons/hicolor/96x96/apps/RBXGAME_${gameID}.png"
  sudo mv "temp8.png" "$HOME/.local/share/icons/hicolor/128x128/apps/RBXGAME_${gameID}.png"

  # Icon cache may not update automatically, so we have to reset icon cache
  echo "Icons in their place, resetting icon cache..."
  sudo update-icon-caches /usr/share/icons/*
  echo "Cache reset, icons ready"
}

get_game_info() {
  echo "Getting game information..."
  local resp=$(curl "https://apis.roblox.com/universes/v1/places/${gameID}/universe")
  universeID=$(echo "$resp" | jq -r ".universeId") # jq used here to get one specific JSON variable

  resp=$(curl "https://games.roblox.com/v1/games?universeIds=${universeID}")
  gameName=$(echo "$resp" | jq -r ".data[0].name")

}

create_desktop_file() {
  echo "Creating .desktop file in current directory..."

  cat >"./rbxgame.${gameID}.desktop" <<EOL
[Desktop Entry]
Name=${gameName}
Comment=Roblox Shortcut for game ${gameID}
Exec=sh -c 'open roblox://placeId=${gameID}'
Icon=RBXGAME_${gameID}
Terminal=false
Type=Application
Categories=Game;

EOL

  echo "Requesting sudo access to mark shortcut as executable (otherwise the shortcut will cry)"
  sudo chmod +x "./rbxgame.${gameID}.desktop"
  if test -d "$HOME/Desktop/"; then
    mv "./rbxgame.${gameID}.desktop" "$HOME/Desktop/"
    echo "Shortcut dropped off at $HOME/Desktop"
  else
    local dir = $(pwd)
    echo "Desktop folder not found, shortcut stays at ${dir}"
  fi

  echo "Shortcut created successfully"
}

#--- THE ACTUALLY IMPORTANT PART ---

create_shortcut() {
  echo "Enter game ID (https://www.roblox.com/games/[[GAME ID]]/Children-Gambling-Online)"
  read -p ">" gameID
  get_game_info
  download_game
  create_desktop_file
}

update_all_shortcuts() {
  local path="$HOME/Desktop"
  while [[ true ]]; do

    if ! test -d "$HOME/Desktop"; then
      echo "No desktop folder found; Where are all the shortcuts located? (provide a file path)"
      read -p ">" path
      if ! test -d path; then
        echo "Path does not exist, there's nothing to iterate through"
      fi
    fi

    break
  done

  local list=($(echo "$path"/rbxgame*))

  echo "Found shortcuts that can be updated: ${list[@]}"

  echo "Starting the update"
  for i in "${list[@]}"; do
    echo "[UPD] Updating shortcut ${i}"
    gameID=$(echo "$i" | sed 's/.desktop//' | sed 's/rbxgame.//')
    gameID="${gameID##*/}"
    get_game_info
    download_game
    rm "${i}"
    create_desktop_file

    echo ""
    echo "Completed iteration ${i}, moving on to the next desktop icon"
    echo ""
  done
}

# any errors will cause the bash script to explode
set -e

echo "-- RBX shortcut creator --"
echo "Checking for required packages..."
# man this is so scuffed
if command -v ffmpeg &>/dev/null; then
  echo "passed"
elif command -v curl &>/dev/null; then
  echo "passed"
elif command -v jq &>/dev/null; then
  echo "passed"
else
  prompt_for_install_packages
fi

echo "Do you want to:"
echo "[1] Create a shortcut"
echo "[2] Update all shortcuts"
read -p ">" entry

if [[ "$entry" == "1" ]]; then
  create_shortcut
elif [[ "$entry" == "2" ]]; then
  update_all_shortcuts
else
  echo "Invalid entry"
fi
