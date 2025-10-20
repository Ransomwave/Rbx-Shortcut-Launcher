# Roblox Game Shortcut Creator

Simple script that creates desktop shortcuts for Roblox games, as if they were real apps installed on your PC. It automatically fetches the **game's name** and **icon** for you!

![Screenshot 1](./assets/screenshot1.png)

## ✨ Features

- 🎮 **Single or Batch Creation** - Create one shortcut or multiple at once
- 🎨 **Custom Shortcut Names** - Rename shortcuts to your preference
- 🔒 **Private Server Support** - Add private server link codes to shortcuts
- 🔄 **Auto-Retry Logic** - Automatically retries API calls if they fail
- 🔍 **Duplicate Detection** - Warns you if a shortcut already exists
- 📦 **Shortcut Updater** - Update existing shortcuts with latest game info and icons

## How to use

### Creating Shortcuts

1. [Download the repository](https://github.com/Ransomwave/Rbx-Shortcut-Launcher/archive/refs/heads/main.zip) or clone it using:
   ```
   git clone https://github.com/Ransomwave/Rbx-Shortcut-Launcher.git
   ```
2. Run the `CreateShortcut.bat` file
3. Choose single or batch mode:
   - **Single mode**: Input one Game ID and optionally customize name and add private server code
   - **Batch mode**: Input multiple Game IDs separated by commas (e.g., `123456,789012,345678`)
4. Input the Game ID(s) _(i.e. https://www.roblox.com/games/**NUMBERHERE**/Your-Game)_
5. Save to desktop or any specified location
6. Enjoy your new Roblox game shortcut(s) with custom icons!

### Updating Shortcuts

1. Run the `UpdateShortcut.bat` file
2. Choose to update:
   - **Single shortcut**: Provide the full path to the .lnk file
   - **All shortcuts in folder**: Specify a folder (default: Desktop)
3. The script will update game names, descriptions, and icons automatically

## Requirements

- Windows 10 or higher
- PowerShell 5.1 or higher
- Internet connection for downloading game icons

## Contributions

Feel free to fork the repository and submit pull requests for improvements or bug fixes.
