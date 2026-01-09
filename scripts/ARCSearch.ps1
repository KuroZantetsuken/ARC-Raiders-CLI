<#
.SYNOPSIS
    ARCSearch - ARC Raiders CLI Data Utility
    Optimized for performance, maintainability, and standard terminal compatibility.

.DESCRIPTION
    Provides a command-line interface to search and view Items, Quests, Hideout Upgrades, and Map Events.
    Uses cached data from the repository.

.EXAMPLE
    .\ARCSearch.ps1 "Durable Cloth"
    .\ARCSearch.ps1 "events"
#>

param (
    [string]$Query
)

# -----------------------------------------------------------------------------
# CONSTANTS & CONFIGURATION
# -----------------------------------------------------------------------------

$RepoRoot       = Resolve-Path (Join-Path $PSScriptRoot "..")
$PathItems      = Join-Path $RepoRoot "data\items"
$PathQuests     = Join-Path $RepoRoot "arcraiders-data\quests"
$PathHideout    = Join-Path $RepoRoot "arcraiders-data\hideout"
$PathEvents     = Join-Path $RepoRoot "arcraiders-data\map-events\map-events.json"

# ANSI Escape Codes (Standard 4-bit/8-bit Palette)
# Using these ensures the tool respects the user's terminal color scheme.
$Theme = @{
    Reset       = "0"
    Bold        = "1"
    
    # Standard Colors
    Black       = "30"; Red         = "31"; Green       = "32"
    Yellow      = "33"; Blue        = "34"; Magenta     = "35"
    Cyan        = "36"; White       = "37"
    
    # Bright Colors
    BrBlack     = "90"; BrRed       = "91"; BrGreen     = "92"
    BrYellow    = "93"; BrBlue      = "94"; BrMagenta   = "95"
    BrCyan      = "96"; BrWhite     = "97"
}

# Semantic Color Mapping
$Palette = @{
    Text        = $Theme.Reset
    Subtext     = $Theme.BrBlack
    Border      = $Theme.BrBlack
    Accent      = $Theme.Yellow
    Success     = $Theme.Green
    Warning     = $Theme.BrYellow
    Error       = $Theme.Red
    
    # Rarity Mapping
    Common      = $Theme.Reset
    Uncommon    = $Theme.BrGreen
    Rare        = $Theme.BrCyan
    Epic        = $Theme.BrMagenta
    Legendary   = $Theme.BrYellow
}

# Symbols
$Sym = @{
    Currency    = "⦶"
    Weight      = "WGT"
    Stack       = "STK"
    Arrow       = "->"
    Box         = @{ H="─"; V="│"; TL="┌"; TR="┐"; BL="└"; BR="┘"; L="├"; R="┤"; C="┼" }
}

# -----------------------------------------------------------------------------
# CORE UTILITIES
# -----------------------------------------------------------------------------

function Write-Ansi {
    param (
        [Parameter(Mandatory=$true)][string]$Text,
        [string]$ColorCode = $Theme.Reset,
        [switch]$NoNewline
    )
    $Esc = [char]27
    $Out = "$Esc[${ColorCode}m$Text$Esc[0m"
    if ($NoNewline) { Write-Host $Out -NoNewline } else { Write-Host $Out }
}

function Get-DisplayLength {
    param ([string]$Text)
    # Remove ANSI codes to calculate visual length
    $Clean = $Text -replace "\x1B\[[0-9;]*[a-zA-Z]", ""
    return $Clean.Length
}

function Import-JsonFast {
    param ([string]$Path)
    if (-not (Test-Path $Path)) { return $null }
    try {
        # .NET ReadAllText is significantly faster than Get-Content for JSON
        $Content = [System.IO.File]::ReadAllText($Path)
        return $Content | ConvertFrom-Json
    } catch {
        return $null
    }
}

# -----------------------------------------------------------------------------
# UI COMPONENTS
# -----------------------------------------------------------------------------

function Write-BoxRow {
    param (
        [string]$Left,
        [string]$Middle,
        [string]$Right,
        [string]$Color = $Palette.Border,
        [int]$Width = 60
    )
    # Repeats middle character to fill width
    $FillLen = $Width - 2
    if ($FillLen -lt 0) { $FillLen = 0 }
    $Line = [string]::new($Middle[0], $FillLen)
    Write-Ansi "$Left$Line$Right" $Color
}

function Write-ContentRow {
    param (
        [string]$Text,
        [string]$TextColor = $Palette.Text,
        [string]$BorderColor = $Palette.Border,
        [int]$Width = 60,
        [string]$Align = "Left" # Left, Center, Right
    )
    $VisLen = Get-DisplayLength $Text
    $PadTotal = $Width - 2 - $VisLen
    if ($PadTotal -lt 0) { $PadTotal = 0 } # Truncation logic should happen before this if needed
    
    $PadL = 0; $PadR = 0
    
    switch ($Align) {
        "Left"   { $PadR = $PadTotal }
        "Right"  { $PadL = $PadTotal }
        "Center" { $PadL = [math]::Floor($PadTotal / 2); $PadR = [math]::Ceiling($PadTotal / 2) }
    }
    
    Write-Ansi $Sym.Box.V $BorderColor -NoNewline
    Write-Ansi "$(' '*$PadL)$Text$(' '*$PadR)" $TextColor -NoNewline
    Write-Ansi $Sym.Box.V $BorderColor
}

function Show-Card {
    param (
        [string]$Title,
        [string]$Subtitle,
        [string[]]$Content,
        [string]$ThemeColor = $Palette.Text,
        [string]$BorderColor = $Palette.Border, # Explicit border color
        [int]$Width = 60
    )
    
    # Top Border
    Write-BoxRow $Sym.Box.TL $Sym.Box.H $Sym.Box.TR $BorderColor $Width
    
    # Title
    if ($Title) {
        $T = $Title.ToUpper()
        if ($T.Length -gt ($Width-4)) { $T = $T.Substring(0, $Width-7) + "..." }
        Write-ContentRow -Text $T -TextColor $ThemeColor -BorderColor $BorderColor -Width $Width
    }
    
    # Subtitle
    if ($Subtitle) {
        Write-ContentRow -Text $Subtitle -TextColor $Palette.Subtext -BorderColor $BorderColor -Width $Width
    }
    
    # Content
    foreach ($Line in $Content) {
        if ($Line -eq "---") {
            Write-BoxRow $Sym.Box.L $Sym.Box.H $Sym.Box.R $BorderColor $Width
        } else {
            # Handle manual coloring embedded in lines, or default to text color
            # If the line already has ANSI codes, we assume the caller handled color.
            # Otherwise we apply the generic Text color.
            $RowColor = if ($Line -match "\x1B\[") { $Theme.Reset } else { $Palette.Text }
            Write-ContentRow -Text $Line -TextColor $RowColor -BorderColor $BorderColor -Width $Width
        }
    }
    
    # Bottom Border
    Write-BoxRow $Sym.Box.BL $Sym.Box.H $Sym.Box.BR $BorderColor $Width
}

# -----------------------------------------------------------------------------
# DATA ENGINE
# -----------------------------------------------------------------------------

# Global Cache
$Global:ItemDB = @{}
$Global:ItemIndexLoaded = $false

function Initialize-ItemIndex {
    if ($Global:ItemIndexLoaded) { return }
    
    # Get all JSON files efficiently
    if (Test-Path $PathItems) {
        $Files = [System.IO.Directory]::GetFiles($PathItems, "*.json")
        foreach ($File in $Files) {
            $Json = Import-JsonFast $File
            if ($Json) { $Global:ItemDB[$Json.id] = $Json }
        }
    }
    $Global:ItemIndexLoaded = $true
}

function Get-ItemName {
    param ($Id)
    if ($Global:ItemDB.ContainsKey($Id)) { return $Global:ItemDB[$Id].name.en }
    return $Id
}

function Get-ItemValue {
    param ($Id)
    if ($Global:ItemDB.ContainsKey($Id)) { return [int]$Global:ItemDB[$Id].value }
    return 0
}

# -----------------------------------------------------------------------------
# FEATURE: ITEMS
# -----------------------------------------------------------------------------

function Show-Item {
    param ($Item)
    $RarityColor = if ($Palette.ContainsKey($Item.rarity)) { $Palette[$Item.rarity] } else { $Palette.Common }
    
    $Lines = @()
    
    # Stats Line
    $Stats = @()
    if ($Item.weightKg)  { $Stats += "$($Sym.Weight) $($Item.weightKg)kg" }
    if ($Item.stackSize) { $Stats += "$($Sym.Stack) $($Item.stackSize)" }
    $Val = if ($Item.value) { $Item.value } else { 0 }
    $Stats += "$($Sym.Currency) $Val"
    $Lines += ($Stats -join "   ")
    $Lines += "---"
    
    # Crafting Math
    if ($Item.recipe) {
        $Cost = 0
        $Item.recipe.PSObject.Properties | ForEach-Object { $Cost += ($_.Value * (Get-ItemValue $_.Name)) }
        $Profit = $Val - $Cost
        $ProfitStr = if ($Profit -ge 0) { "+$Profit" } else { "$Profit" }
        $Lines += "Craft Cost: $($Sym.Currency) $Cost ($ProfitStr)"
    }
    
    # Values
    $ProcessTypes = @{ "recyclesInto" = "Recycle"; "salvagesInto" = "Salvage" }
    foreach ($Key in $ProcessTypes.Keys) {
        if ($Item.$Key) {
            $PVal = 0
            $Item.$Key.PSObject.Properties | ForEach-Object { $PVal += ($_.Value * (Get-ItemValue $_.Name)) }
            $Diff = $PVal - $Val
            $Lines += "$($ProcessTypes[$Key]) Value: $($Sym.Currency) $PVal ($Diff)"
        }
    }
    
    if ($null -ne $Item.stashSavings) {
        $Sv = "{0:N4}" -f $Item.stashSavings
        $Sign = if ($Item.stashSavings -gt 0) { "+" } else { "" }
        $Lines += "Stash Savings: $Sign$Sv slots"
    }
    
    # Ingredients / Results Lists
    $Lists = @{ "recipe" = "RECIPE"; "recyclesInto" = "RECYCLES INTO"; "salvagesInto" = "SALVAGES INTO" }
    foreach ($Key in $Lists.Keys) {
        if ($Item.$Key) {
            $Lines += "---"
            $Lines += "$($Lists[$Key]):"
            $Item.$Key.PSObject.Properties | ForEach-Object {
                $Lines += " - $($_.Value)x $(Get-ItemName $_.Name)"
            }
        }
    }
    
    # Description (Wrapped)
    if ($Item.description.en) {
        $Lines += "---"
        $Desc = $Item.description.en
        $MaxLen = 56
        $Offset = 0
        while ($Offset -lt $Desc.Length) {
            $Len = [math]::Min($MaxLen, $Desc.Length - $Offset)
            $Lines += $Desc.Substring($Offset, $Len)
            $Offset += $Len
        }
    }
    
    Show-Card -Title $Item.name.en `
              -Subtitle "$($Item.rarity) $($Item.type)" `
              -Content $Lines `
              -ThemeColor $RarityColor `
              -BorderColor $RarityColor
}

# -----------------------------------------------------------------------------
# FEATURE: EVENTS
# -----------------------------------------------------------------------------

function Show-Events {
    if (-not (Test-Path $PathEvents)) { Write-Ansi "Event data missing." $Palette.Error; return }
    
    $Data = Import-JsonFast $PathEvents
    $Sched = $Data.schedule
    $Types = $Data.eventTypes
    $Maps  = $Data.maps
    
    $TimeNow = [DateTime]::UtcNow
    $Hour = $TimeNow.Hour
    $LocalTime = [DateTime]::Now.ToString("HH:mm")
    
    # We build the UI manually using the drawing primitives to handle the specific layout requirements
    $W = 60
    
    # 1. Header
    Write-BoxRow $Sym.Box.TL $Sym.Box.H $Sym.Box.TR $Palette.Border $W
    Write-ContentRow -Text "EVENT SCHEDULE" -TextColor $Palette.Accent -BorderColor $Palette.Border -Align "Center" $W
    Write-BoxRow $Sym.Box.L $Sym.Box.H $Sym.Box.R $Palette.Border $W
    
    # 2. Active Events
    Write-ContentRow -Text " ACTIVE NOW ($LocalTime)" -TextColor $Palette.Success -BorderColor $Palette.Border $W
    Write-BoxRow $Sym.Box.L $Sym.Box.H $Sym.Box.R $Palette.Border $W
    
    foreach ($MapKey in $Sched.PSObject.Properties.Name) {
        $MapName = if ($Maps.$MapKey.displayName) { $Maps.$MapKey.displayName } else { $MapKey }
        $MajorKey = $Sched.$MapKey.major."$Hour"
        $MinorKey = $Sched.$MapKey.minor."$Hour"
        
        if ($MajorKey -or $MinorKey) {
            # Map Header
            Write-ContentRow -Text " $MapName" -TextColor $Palette.Text -BorderColor $Palette.Border $W
            
            if ($MajorKey) {
                $Name = $Types.$MajorKey.displayName
                Write-ContentRow -Text "   Major: $Name" -TextColor $Palette.Subtext -BorderColor $Palette.Border $W
            }
            if ($MinorKey) {
                $Name = $Types.$MinorKey.displayName
                Write-ContentRow -Text "   Minor: $Name" -TextColor $Palette.Accent -BorderColor $Palette.Border $W
            }
            Write-BoxRow $Sym.Box.L $Sym.Box.H $Sym.Box.R $Palette.Border $W
        }
    }
    
    # 3. Upcoming
    Write-ContentRow -Text " UPCOMING SCHEDULE" -TextColor $Palette.Accent -BorderColor $Palette.Border $W
    
    # Table Separator
    # 7 | 30 | 21
    $Sep = "$($Sym.Box.L)$([string]::new($Sym.Box.H, 7))$($Sym.Box.C)$([string]::new($Sym.Box.H, 30))$($Sym.Box.C)$([string]::new($Sym.Box.H, 21))$($Sym.Box.R)"
    Write-Ansi $Sep $Palette.Border
    
    # Calculate Upcoming
    $List = @()
    foreach ($EKey in $Types.PSObject.Properties.Name) {
        if ($EKey -eq "none" -or $Types.$EKey.disabled) { continue }
        
        # Find next occurrence
        $BestH = 999; $Next = $null
        foreach ($MKey in $Sched.PSObject.Properties.Name) {
            foreach ($Cat in @("major", "minor")) {
                $S = $Sched.$MKey.$Cat
                if (-not $S) { continue }
                for ($i=0; $i -lt 24; $i++) {
                    if ($S."$(($Hour + $i) % 24)" -eq $EKey) {
                        if ($i -lt $BestH) {
                            $BestH = $i
                            $Next = @{
                                Name = $Types.$EKey.displayName
                                Map  = if ($Maps.$MKey.displayName) { $Maps.$MKey.displayName } else { $MKey }
                                Time = $TimeNow.AddHours($i)
                                Cat  = $Types.$EKey.category
                            }
                        }
                    }
                }
            }
        }
        if ($Next) { $List += [PSCustomObject]$Next }
    }
    
    $List = $List | Sort-Object Time
    
    # Render Rows
    foreach ($Ev in $List) {
        $TStr = if (($Ev.Time - $TimeNow).TotalHours -lt 1) { " NOW " } else { $Ev.Time.ToLocalTime().ToString("HH:mm") }
        $EvColor = if ($Ev.Cat -eq "major") { $Palette.Text } else { $Palette.Subtext }
        
        # Row Construction
        Write-Ansi $Sym.Box.V $Palette.Border -NoNewline
        Write-Ansi $TStr.PadRight(7) $Palette.Accent -NoNewline
        Write-Ansi $Sym.Box.V $Palette.Border -NoNewline
        
        $N = $Ev.Name; if ($N.Length -gt 30) { $N = $N.Substring(0, 27) + "..." }
        Write-Ansi $N.PadRight(30) $EvColor -NoNewline
        Write-Ansi $Sym.Box.V $Palette.Border -NoNewline
        
        $M = $Ev.Map; if ($M.Length -gt 21) { $M = $M.Substring(0, 18) + "..." }
        Write-Ansi $M.PadRight(21) $Palette.Subtext -NoNewline
        Write-Ansi $Sym.Box.V $Palette.Border
        
        # Separator (except last)
        if ($Ev -ne $List[-1]) { Write-Ansi $Sep $Palette.Border }
    }
    
    # Bottom
    $Bot = "$($Sym.Box.BL)$([string]::new($Sym.Box.H, 7))$($Sym.Box.B)$([string]::new($Sym.Box.H, 30))$($Sym.Box.B)$([string]::new($Sym.Box.H, 21))$($Sym.Box.BR)"
    Write-Ansi $Bot $Palette.Border
}

# -----------------------------------------------------------------------------
# MAIN CONTROLLER
# -----------------------------------------------------------------------------

if ([string]::IsNullOrWhiteSpace($Query)) {
    Write-Ansi "Usage: ARCSearch <Query>" $Palette.Warning
    exit
}

if ($Query -eq "events") {
    Show-Events
    exit
}

Write-Ansi "Searching..." $Palette.Subtext
Initialize-ItemIndex

$Results = @()

# 1. Search Items
foreach ($Item in $Global:ItemDB.Values) {
    if ($Item.name.en -like "*$Query*" -or $Item.id -eq $Query) {
        $Results += [PSCustomObject]@{ Type="Item"; Name=$Item.name.en; Data=$Item }
    }
}

# 2. Search Quests
if (Test-Path $PathQuests) {
    Get-ChildItem $PathQuests "*.json" | ForEach-Object {
        $J = Import-JsonFast $_.FullName
        if ($J -and $J.name.en -like "*$Query*") {
            $Results += [PSCustomObject]@{ Type="Quest"; Name=$J.name.en; Data=$J }
        }
    }
}

# 3. Search Hideout
if (Test-Path $PathHideout) {
    Get-ChildItem $PathHideout "*.json" | ForEach-Object {
        $J = Import-JsonFast $_.FullName
        if ($J -and $J.name.en -like "*$Query*") {
            $Results += [PSCustomObject]@{ Type="Hideout"; Name=$J.name.en; Data=$J }
        }
    }
}

# Result Handling
if ($Results.Count -eq 0) {
    Write-Ansi "No results found." $Palette.Error
} elseif ($Results.Count -eq 1) {
    $T = $Results[0]
    switch ($T.Type) {
        "Item"    { Show-Item $T.Data }
        "Quest"   { 
            # Inline Quest Render for simplicity
            $Q = $T.Data
            $C = @("TRADER: $($Q.trader)", "---")
            if ($Q.objectives) { $C += "OBJECTIVES:"; foreach($o in $Q.objectives){if($o.en){$C+=" [ ] $($o.en)"}} }
            Show-Card -Title $Q.name.en -Subtitle "Quest" -Content $C -ThemeColor $Palette.Accent
        }
        "Hideout" {
            # Inline Hideout Render
            $H = $T.Data
            $C = @("UPGRADES:")
            foreach($L in $H.levels){ $C+=" Level $($L.level)" } # Simplified for brevity
            Show-Card -Title $H.name.en -Subtitle "Hideout" -Content $C -ThemeColor $Palette.Accent
        }
    }
} else {
    Write-Ansi "SEARCH RESULTS" $Palette.Accent
    for ($i=0; $i -lt $Results.Count; $i++) {
        if ($i -ge 10) { Write-Ansi "... and more" $Palette.Subtext; break }
        Write-Ansi " [$i] " $Palette.Accent -NoNewline
        Write-Ansi "$($Results[$i].Name) " $Palette.Text -NoNewline
        Write-Ansi "($($Results[$i].Type))" $Palette.Subtext
    }
    
    # Selection Logic
    Write-Ansi "`nSelect (0-9): " $Palette.Accent -NoNewline
    try {
        $Host.UI.RawUI.FlushInputBuffer()
        $Key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        if ($Key.Character -match "[0-9]") {
            $Idx = [int][string]$Key.Character
            Write-Host $Idx
            if ($Idx -lt $Results.Count) {
                $T = $Results[$Idx]
                # Recursively call logic or just copy paste render switch (safest to copy paste for this script structure)
                 switch ($T.Type) {
                    "Item"    { Show-Item $T.Data }
                    "Quest"   { 
                        $Q = $T.Data
                        $C = @("TRADER: $($Q.trader)", "---")
                        if ($Q.objectives) { $C += "OBJECTIVES:"; foreach($o in $Q.objectives){if($o.en){$C+=" [ ] $($o.en)"}} }
                        Show-Card -Title $Q.name.en -Subtitle "Quest" -Content $C -ThemeColor $Palette.Accent
                    }
                    "Hideout" {
                        $H = $T.Data
                        $C = @("UPGRADES:")
                        foreach($L in $H.levels){ $C+=" Level $($L.level)" }
                        Show-Card -Title $H.name.en -Subtitle "Hideout" -Content $C -ThemeColor $Palette.Accent
                    }
                }
            }
        }
    } catch {}
}

