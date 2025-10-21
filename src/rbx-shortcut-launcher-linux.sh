# NOTE: This is very plain, make it look good later thank you :3

# NOTE: Only Arch (pacman), Debian (dnf), and Ubuntu (apt) (and it's deviations, like Mint) are supported. Some random linux distributions with 10 downloads and with a custom package manager are NOT supported
install_packages() {
  source /etc/os-release # get name for distro
  echo "please give us root permissions :3"

  if $ID == "ubuntu"; then
    sudo apt install ffmpeg curl
  elif $ID == "arch"; then
    sudo pacman -S ffmpeg curl
  elif $ID == "debian"; then
    sudo dnf install ffmpeg curl
  else
    echo "Distro NOT supported, install curl and ffmpeg please"
    exit 1
  fi

  clear
}

prompt_for_install_packages() {
  echo "No packages found. Do you want to install packages? (Arch, Debian and Ubuntu (and it's deviations) only)"
  read -p "Y/N >>>" prompt
  if prompt == "Y"; then
    install_packages
  else
    echo "Accepted. Install ffmpeg and curl please"
    exit 1
  fi
}

does_command_exist() {
  let cmdName=$1
  if command -v cmdName &>/dev/null; then
    echo "true"
  else
    echo "false"
  fi
}

# downloading game 😱
download_game() {
  local gameID=$1 # this is how we declare function arguments
  echo "Initiating game image download"
}

create_desktop_file() {

}

echo "-- RBX shortcut launcher --"
echo "Checking for required packages..."
if $(does_command_exist "ffmpeg") == "false"; then
  prompt_for_install_packages
elif $(does_command_exist "curl") == "false"; then
  prompt_for_install_packages
fi
echo "Enter game ID (https://www.roblox.com/games/[[GAME ID]]/Children-Gambling-Online)"
read gameID
