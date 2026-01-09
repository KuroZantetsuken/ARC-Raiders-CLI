# ARC Raiders Data CLI & Stash Optimizer

This utility helps players of ARC Raiders optimize their stash space and quickly lookup game information like items, quests, hideouts, and active events.

## Features

- **Stash Savings Calculation**: Automatically calculates the net stash space gained or lost by crafting items.
- **Universal Search**: Quickly find Items, Quests, and Hideouts using `ARCSearch`.
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

3.  **Run Calculation Script**:
    ```bash
    python scripts/calculate_savings.py
    ```

4.  **Add to PATH (Recommended)**:
    Add the `scripts` folder to your System PATH to use `ARCSearch` from anywhere (e.g., PowerToys Run).

## Usage

### Search Items, Quests, Hideouts

```powershell
ARCSearch "Herbal Bandage"
```

If multiple results are found, simply press the corresponding number key (0-9) to select instantly.

### Check Event Schedule

```powershell
ARCSearch events
```
Displays current and next major/minor events for all maps in your local time.

### Examples

- `ARCSearch scrappy` -> Shows Scrappy hideout upgrades.
- `ARCSearch "down to earth"` -> Shows quest objectives and rewards.
- `ARCSearch heavy` -> Lists Heavy Ammo, Heavy Shield, etc.

## Project Structure

- `arcraiders-data`: Submodule containing original game data.
- `data/items`: Generated data with `stashSavings` added.
- `scripts/calculate_savings.py`: Python script for processing data.
- `scripts/ARCSearch.ps1`: The main CLI tool.
