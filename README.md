# ARC Raiders Data CLI & Stash Optimizer

This utility helps players of ARC Raiders optimize their stash space and quickly lookup game information like items, quests, hideouts, and active events.

## Features

- **Stash Savings Calculation**: Automatically calculates the net stash space gained or lost by crafting items (on-the-fly).
- **Universal Search**: Quickly find Items, Bots, Projects, Skills, Trades, Quests, and Hideouts using `ARCSearch`.
- **Event Schedule**: View active and upcoming map events converted to your local time.
- **Interactive CLI**: Fast result selection designed for quick access while playing.

## Setup

1.  **Clone the Repository**:
    ```bash
    git clone https://github.com/KuroZantetsuken/ARC-Raiders-Data-CLI.git
    cd ARC-Raiders-Data-CLI
    ```

2.  **Initialize Data Source**:
    ```bash
    git submodule update --init --recursive
    ```

3.  **Run the Tool**:
    ```powershell
    .\ARCSearch.ps1 "Herbal Bandage"
    ```

## Usage

### Search Items, Quests, Hideouts

```powershell
.\ARCSearch.ps1 "Herbal Bandage"
```

If multiple results are found, simply press the corresponding number key (0-9) to select instantly.

### Check Event Schedule

```powershell
.\ARCSearch.ps1 events
```
Displays current and next major/minor events for all maps in your local time.

### Examples

- `.\ARCSearch.ps1 scrappy` -> Shows Scrappy hideout upgrades.
- `.\ARCSearch.ps1 "down to earth"` -> Shows quest objectives and rewards.
- `.\ARCSearch.ps1 heavy` -> Lists Heavy Ammo, Heavy Shield, etc.
- `.\ARCSearch.ps1 celeste` -> Shows info about Celeste (Trader) or Celeste's Journal (Item).

## Project Structure

- `arcraiders-data`: Submodule containing game data.
- `ARCSearch.ps1`: The main CLI tool with built-in stash optimizer logic.
