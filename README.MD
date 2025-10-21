# Roblox Game Shortcut Creator

Simple script that creates desktop shortcuts for Roblox games, as if they were real apps installed on your PC. It automatically fetches the **game's name** and **icon** for you!

![Screenshot 1](./assets/screenshot1.png)

## How to use

### Windows

1. [Download the repository](https://github.com/Ransomwave/Rbx-Shortcut-Launcher/archive/refs/heads/main.zip) or clone it using:
   ```
   git clone https://github.com/Ransomwave/Rbx-Shortcut-Launcher.git
   ```
2. Run the `CreateShortcut.bat` or the `src/rbx-shortcut-launcher-linux.sh` file
3. Input the Game ID _(i.e. https://www.roblox.com/games/**NUMBERHERE**/Your-Game)_
4. Save it to the desktop or any specified location
5. Enjoy your new Roblox game shortcut with a custom icon, as if it were a real app!

### Linux

1. [Download the repository](https://github.com/Ransomwave/Rbx-Shortcut-Launcher/archive/refs/heads/main.zip) or clone it using:
   ```
   git clone https://github.com/Ransomwave/Rbx-Shortcut-Launcher.git
   ```
2. Run `chmod +x ./src/rbx-shortcut-launcher-linux.sh` to give it ability to execute
3. Run `./src/rbx-shortcut-launcher-linux.sh`
4. Input the Game ID _(i.e. https://www.roblox.com/games/**NUMBERHERE**/Your-Game)_
5. Save it to the desktop or any specified location
6. Enjoy your new Roblox game shortcut with a custom icon, as if it were a real app!

## Requirements

- Windows 10 or higher, **OR** any respectable and recognized Linux distribution with no package manager deviations, and with a DE that supports `.desktop` files
- PowerShell 5.1 or higher, **OR** respectable version of Bash, ffmpeg (image conversion), curl (web requests) and jq (json filtering)
- Internet connection for downloading game icons

## Contributions

Feel free to fork the repository and submit pull requests for improvements or bug fixes.
