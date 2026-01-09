# ARC Raiders Data CLI

A lightweight, fast, and intuitive CLI tool for **ARC Raiders**. Quickly look up items, crafting recipes, quest objectives, and check the live map event schedule directly from your terminal.

![Demo Video](.assets/demo.webp)

## Features

*   **Smart Search**: Look up Items, ARCs, Quests, and more with simple key words.
*   **Stash Optimizer**: Real-time math on every item. See if crafting saves or costs stash slots.
*   **Deep Analysis**:
    *   **Currency Conversion**: Compare prices to Coins even if the item is sold for a different item.
    *   **Crafting Cost**: Calculates total raw ingredient costs.
    *   **Recycling & Salvage**: Compares the value of an item vs. breaking it down.
*   **Event Schedule**: Live schedule of Map Events (Major & Minor) in your local time.
*   **Trade Profit**: Shows if a trade is profitable based on market values.
*   **Rich UI**: Pleasant terminal output with colors, badges, and card-based layouts.

## Installation

### Option 1: Quick Download (Recommended)
1.  **Download the latest release**: [arc-raiders-cli.zip](https://github.com/KuroZantetsuken/ARC-Raiders-Data-CLI/releases/latest/download/arc-raiders-cli.zip)
2.  **Extract** the ZIP to a folder of your choice.
3.  **Run Setup**:
    *   Right-click `Setup.ps1` and select **Run with PowerShell**, or run `.\Setup.ps1` in a terminal.
    *   This adds the tool to your `PATH` and creates the `arc` command.
4.  **Restart Terminal**: Close and reopen your terminal.

### Option 2: Developers (Git)
1.  **Clone the Repo**:
    ```powershell
    git clone --recursive https://github.com/KuroZantetsuken/ARC-Raiders-Data-CLI.git
    cd ARC-Raiders-Data-CLI
    ```
2.  **Run Setup**: `.\Setup.ps1`

## Usage Guide

### 1. Searching
Type `arc` followed by any keyword.
```powershell
arc heavy        # Lists results matching "Heavy"
arc shredder     # Shows ARC stats for "Shredder"
arc "to earth"   # Finds quest "Down To Earth"
```
*   **Selection**: If multiple results are found, simply press `0`-`9` to make your selection.
*   **Direct Access**: You can also specify the index directly in the command.
    ```powershell
    arc shield 0     # Immediately opens the first result for "shield"
    ```

### 2. Lookup Capabilities
The tool automatically detects what you are searching for and displays the relevant card:

*   **Items**: View stats, weight, stack size, and detailed value analysis.
    *   *Stash Optimizer*: Shows net stash space gain/loss from crafting.
    *   *Crafting Analysis*: Breakdown of ingredient costs vs. item value.
    *   *Recycling/Salvage*: Shows if it's better to sell or recycle.
    *   *Market Data*: Shows who sells it and how badly you're ripped off (Coins/Creds/Barter).
*   **ARCs**: View threat level, type, weakness description, drops, and locations.
*   **Quests**: View Trader, Objectives, and Rewards.
*   **Hideout**: View upgrade levels and requirements.
*   **Projects**: View phases, resource requirements, and descriptions.
*   **Skills**: View category, max points, and impacted skills.

### 4. Event Schedule
View the upcoming times for all events.
```powershell
arc events
```
*   Shows the **Next Occurrence** of every event type.
*   Times are in **Your Local Time**.
*   Map coloring based on **in-game key card color**.

### 5. Integration (PowerToys Run)
Since `Setup.ps1` adds the folder to your PATH, you can use **PowerToys Run** (Alt+Space):
1.  Type `> arc events`
2.  Hit Enter to see the schedule immediately.

## Updates
Game data changes often. To update to the latest values:
```powershell
cd ARC-Raiders-Data-CLI
git submodule update --remote
```

## Uninstalling
To cleanly remove the tool and all system changes:
```powershell
.\Setup.ps1 -Uninstall
```
*   Removes the folder from your `PATH`.
*   Deletes the `arc` alias.
*   You can then safely delete the project folder.

## Credits & Attribution
This tool uses game data provided by the [RaidTheory/arcraiders-data](https://github.com/RaidTheory/arcraiders-data) project.
Special thanks to the team at [arctracker.io](https://arctracker.io) for their work in compiling and maintaining this resource.

## Project Structure
*   `ARCSearch.ps1`: The core PowerShell engine.
*   `arc.bat`: Wrapper for easy invocation.
*   `arcraiders-data/`: Linked submodule containing raw JSON data.
