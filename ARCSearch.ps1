<#
.SYNOPSIS
    ARCSearch - ARC Raiders CLI Data Utility
    Optimized for performance, maintainability, and standard terminal compatibility.

.DESCRIPTION
    Provides a command-line interface to search and view Items, Quests, Hideout Upgrades, Map Events, Bots, Projects, Skills, and Trades.

.EXAMPLE
    .\ARCSearch.ps1 "Durable Cloth"
    .\ARCSearch.ps1 "events"
    .\ARCSearch.ps1 "Celeste"
#>

param (
    [string]$Query,
    [int]$SelectIndex = -1
)

# -----------------------------------------------------------------------------
# CONSTANTS & CONFIGURATION
# -----------------------------------------------------------------------------

$RepoRoot       = $PSScriptRoot
$PathItems      = Join-Path $RepoRoot "arcraiders-data\items"
$PathQuests     = Join-Path $RepoRoot "arcraiders-data\quests"
$PathHideout    = Join-Path $RepoRoot "arcraiders-data\hideout"
$PathEvents     = Join-Path $RepoRoot "arcraiders-data\map-events\map-events.json"
$PathBots       = Join-Path $RepoRoot "arcraiders-data\bots.json"
$PathProjects   = Join-Path $RepoRoot "arcraiders-data\projects.json"
$PathSkills     = Join-Path $RepoRoot "arcraiders-data\skillNodes.json"
$PathTrades     = Join-Path $RepoRoot "arcraiders-data\trades.json"

# ANSI Escape Codes
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
    Common      = $Theme.BrBlack  # Grey for Common
    Uncommon    = $Theme.BrGreen
    Rare        = $Theme.BrCyan
    Epic        = $Theme.BrMagenta
    Legendary   = $Theme.BrYellow
}

# Symbols
$Sym = @{
    Currency    = [char]0x29B6 # ⦶
    Creds       = [char]0x24D1 # ⓑ
    Weight      = "WGT"
    Stack       = "STK"
    Arrow       = "->"
    Box         = @{ 
        H = [char]0x2500
        V = [char]0x2502
        TL = [char]0x250C
        TR = [char]0x2510
        BL = [char]0x2514
        BR = [char]0x2518
        L = [char]0x251C
        R = [char]0x2524
        C = [char]0x253C
        T = [char]0x252C
        B = [char]0x2534
    }
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
        $Content = [System.IO.File]::ReadAllText($Path)
        return $Content | ConvertFrom-Json
    } catch {
        return $null
    }
}

function Get-WrappedText {
    param (
        [string]$Text,
        [int]$Width = 55,
        [string]$Indent = " "
    )
    if (-not $Text) { return @() }
    
    $Lines = @()
    $Words = $Text -split ' '
    $CurrentLine = ""
    
    foreach ($Word in $Words) {
        $SpaceLen = if ($CurrentLine.Length -gt 0) { 1 } else { 0 }
        if (($CurrentLine.Length + $SpaceLen + $Word.Length) -le $Width) {
            if ($SpaceLen -eq 1) { $CurrentLine += " " }
            $CurrentLine += $Word
        } else {
            if ($CurrentLine.Length -gt 0) { $Lines += ($Indent + $CurrentLine) }
            $CurrentLine = $Word
            while ($CurrentLine.Length -gt $Width) {
                $Lines += ($Indent + $CurrentLine.Substring(0, $Width))
                $CurrentLine = $CurrentLine.Substring($Width)
            }
        }
    }
    if ($CurrentLine.Length -gt 0) { $Lines += ($Indent + $CurrentLine) }
    
    return $Lines
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
    if ($PadTotal -lt 0) { $PadTotal = 0 } 
    
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
        [string]$BorderColor = $Palette.Border,
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
            # Handle manual coloring embedded in lines
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

$Global:Data = @{
    Items    = @{}
    Bots     = @()
    Projects = @()
    Skills   = @()
    Trades   = @()
}
$Global:DataLoaded = $false

function Initialize-Data {
    if ($Global:DataLoaded) { return }
    
    # 1. Items
    if (Test-Path $PathItems) {
        $Files = [System.IO.Directory]::GetFiles($PathItems, "*.json")
        foreach ($File in $Files) {
            $Json = Import-JsonFast $File
            if ($Json) { $Global:Data.Items[$Json.id] = $Json }
        }
    }

    # 2. Other Data
    if (Test-Path $PathBots)     { $Global:Data.Bots     = Import-JsonFast $PathBots }
    if (Test-Path $PathProjects) { $Global:Data.Projects = Import-JsonFast $PathProjects }
    if (Test-Path $PathSkills)   { $Global:Data.Skills   = Import-JsonFast $PathSkills }
    if (Test-Path $PathTrades)   { $Global:Data.Trades   = Import-JsonFast $PathTrades }

    $Global:DataLoaded = $true
}

function Get-ItemName {
    param ($Id)
    if ($Global:Data.Items.ContainsKey($Id)) { return $Global:Data.Items[$Id].name.en }
    return $Id -replace "_", " " -replace "\b\w", { $args[0].Value.ToUpper() }
}

function Get-ItemValue {
    param ($Id)
    if ($Id -eq "coins" -or $Id -eq "creds") { return 1 }
    if ($Global:Data.Items.ContainsKey($Id)) { return [int]$Global:Data.Items[$Id].value }
    return 0
}

function Get-ItemSlotUsage {
    param ($Id, $Quantity)
    if (-not $Global:Data.Items.ContainsKey($Id)) { return 0 }
    $StackSize = $Global:Data.Items[$Id].stackSize
    if (-not $StackSize -or $StackSize -eq 0) { $StackSize = 1 }
    return $Quantity / $StackSize
}

function Get-StashSpaceDelta {
    param ($Item)
    if (-not $Item.recipe) { return $null }
    $IngSlots = 0
    $Item.recipe.PSObject.Properties | ForEach-Object {
        $IngSlots += (Get-ItemSlotUsage -Id $_.Name -Quantity $_.Value)
    }
    $Yield = if ($Item.craftQuantity) { $Item.craftQuantity } else { 1 }
    $ResSlots = Get-ItemSlotUsage -Id $Item.id -Quantity $Yield
    return $ResSlots - $IngSlots
}

function Get-FormattedBadge {
    param ($Text, $ColorKey)
    $ColorCode = if ($Palette.ContainsKey($ColorKey)) { $Palette[$ColorKey] } else { $Palette.Common }
    $Esc = [char]27
    
    # Always format with background for consistency and readability
    $BgCode = [int]$ColorCode + 10
    return "$Esc[${BgCode};30m $Text $Esc[0m"
}

function Format-DiffString {
    param ([int]$Value, [bool]$InvertColors = $false)
    $Esc = [char]27
    $Sign = if ($Value -gt 0) { "+" } else { "" }
    
    # Default: Positive is Good (Green), Negative is Bad (Red)
    # Inverted: Positive is Bad (Red), Negative is Good (Green)
    
    $Color = $Palette.Text
    if ($InvertColors) {
        if ($Value -gt 0) { $Color = $Palette.Error } # Bad (More expensive)
        elseif ($Value -lt 0) { $Color = $Palette.Success } # Good (Cheaper)
    } else {
        if ($Value -gt 0) { $Color = $Palette.Success } # Good (Profit)
        elseif ($Value -lt 0) { $Color = $Palette.Error } # Bad (Loss)
    }
    
    # Only color the number
    return "($Esc[${Color}m$Sign$Value$Esc[0m)"
}

# -----------------------------------------------------------------------------
# DISPLAY LOGIC
# -----------------------------------------------------------------------------

function Show-Item {
    param ($Item)
    $Esc = [char]27
    $RarityColor = if ($Palette.ContainsKey($Item.rarity)) { $Palette[$Item.rarity] } else { $Palette.Common }
    $Indent = " "
    $Lines = @()

    # Header
    $Badge1 = Get-FormattedBadge -Text $Item.type -ColorKey $Item.rarity
    $Badge2 = Get-FormattedBadge -Text $Item.rarity -ColorKey $Item.rarity
    $Lines += ($Indent + "$Badge1 $Badge2")
    
    # Name
    $Lines += ($Indent + $Item.name.en.ToUpper())
    
    # Description
    if ($Item.description.en) {
        $Lines += (Get-WrappedText -Text $Item.description.en -Indent $Indent)
    }
    
    # Effects
    if ($Item.effects) {
        $EffLines = @()
        foreach ($Key in $Item.effects.PSObject.Properties.Name) {
            if ($Key -eq "Durability") { continue }
            $Eff = $Item.effects.$Key
            $Label = if ($Eff.en) { $Eff.en } else { $Key }
            if ($Eff.value) { $EffLines += ($Indent + "$($Label): $($Eff.value)") }
        }
        if ($EffLines.Count -gt 0) { $Lines += "---"; $Lines += $EffLines }
    }
    
    # Properties
    $Lines += "---"
    $Props = @()
    if ($Item.stackSize) { $Props += "$($Sym.Stack) $($Item.stackSize)" }
    if ($Item.weightKg)  { $Props += "$($Sym.Weight) $($Item.weightKg)kg" }
    $Val = if ($Item.value) { $Item.value } else { 0 }
    $Props += "$($Sym.Currency) $Val"
    $Lines += ($Indent + ($Props -join "   "))
    
    # Crafting
    if ($Item.recipe) {
        $Lines += "---"
        $Lines += ($Indent + "Recipe:")
        $Cost = 0
        $Item.recipe.PSObject.Properties | ForEach-Object { 
            $Lines += ($Indent + " - $($_.Value)x $(Get-ItemName $_.Name)")
            $Cost += ($_.Value * (Get-ItemValue $_.Name)) 
        }
        
        # Profit = Value - Cost. Negative is Bad (Red).
        $ProfitDiff = $Val - $Cost
        $DiffStr = Format-DiffString -Value $ProfitDiff -InvertColors $false
        
        $Lines += ($Indent + "Cost: $($Sym.Currency) $Cost $DiffStr")

        $Delta = Get-StashSpaceDelta -Item $Item
        if ($null -ne $Delta) {
            $DeltaVal = "{0:0.##}" -f $Delta
            # Delta > 0 (More space) is Bad (Red). Delta < 0 (Less space) is Good (Green).
            $Msg = ""
            if ($Delta -gt 0) {
                $Msg = "Space: $Esc[$($Palette.Error)m$DeltaVal$Esc[0m more slots"
            } elseif ($Delta -lt 0) {
                $Msg = "Space: $Esc[$($Palette.Success)m$DeltaVal$Esc[0m slots"
            } else {
                $Msg = "Space: 0 slots"
            }
            $Lines += ($Indent + $Msg)
        }
    }
    
    # Recycling
    $ProcessTypes = @{ "recyclesInto" = "Recycles Into"; "salvagesInto" = "Salvages Into" }
    foreach ($Key in $ProcessTypes.Keys) {
        if ($Item.$Key -and $Item.$Key.PSObject.Properties.Count -gt 0) {
            $Lines += "---"
            $Lines += ($Indent + "$($ProcessTypes[$Key]):")
            $PVal = 0
            $Item.$Key.PSObject.Properties | ForEach-Object {
                $Lines += ($Indent + " - $($_.Value)x $(Get-ItemName $_.Name)")
                $PVal += ($_.Value * (Get-ItemValue $_.Name))
            }
            
            # Diff = RecycleValue - BaseValue. Positive is Good (Green).
            $RecycDiff = $PVal - $Val
            $DiffStr = Format-DiffString -Value $RecycDiff -InvertColors $false
            
            $Lines += ($Indent + "Value: $($Sym.Currency) $PVal $DiffStr")
        }
    }

    # Sold By (Trades)
    $ItemTrades = $Global:Data.Trades | Where-Object { $_.itemId -eq $Item.id }
    
    if ($ItemTrades) {
        # Determine Market Value (Coins) if available
        $CoinTrade = $ItemTrades | Where-Object { $_.cost.itemId -eq "coins" } | Select-Object -First 1
        $MarketValue = if ($CoinTrade) { $CoinTrade.cost.quantity } else { $null }
        
        $Lines += "---"
        $Lines += ($Indent + "Sold By:")
        foreach ($Trade in $ItemTrades) {
            $Trader = $Trade.trader
            $LimitStr = if ($Trade.dailyLimit) { "$($Trade.dailyLimit)x " } else { "" }
            $Lines += ($Indent + " - $LimitStr$Trader")
            
            $CostId = $Trade.cost.itemId
            $CostQty = $Trade.cost.quantity
            
            if ($CostId -eq "coins") {
                $Diff = $CostQty - $Val
                $DiffStr = Format-DiffString -Value $Diff -InvertColors $true
                $Lines += ($Indent + "Price: $($Sym.Currency) $CostQty $DiffStr")
            } elseif ($CostId -eq "creds") {
                $ExchStr = ""
                if ($MarketValue) {
                    $Rate = [math]::Round($MarketValue / $CostQty, 2)
                    $ExchStr = "($($Sym.Creds) 1 = $($Sym.Currency) $Rate)"
                }
                $Lines += ($Indent + "Price: $($Sym.Creds) $CostQty $ExchStr")
            } else {
                # Barter
                $CostItemVal = Get-ItemValue $CostId
                $TotalCostVal = $CostQty * $CostItemVal
                $Diff = $TotalCostVal - $Val
                
                # Barter Diff Format: (⦶ +50)
                $Sign = if ($Diff -gt 0) { "+" } else { "" }
                $Color = $Palette.Text
                if ($Diff -gt 0) { $Color = $Palette.Error }
                elseif ($Diff -lt 0) { $Color = $Palette.Success }
                
                $DiffDisplay = "($($Sym.Currency) $Esc[${Color}m$Sign$Diff$Esc[0m)"
                $CostName = Get-ItemName $CostId
                $Lines += ($Indent + "Price: ${CostQty}x $CostName $DiffDisplay")
            }
        }
    }
    
    Show-Card -Title $null -Subtitle $null -Content $Lines -ThemeColor $RarityColor -BorderColor $RarityColor
}

function Show-Bot {
    param ($Bot)
    $ThreatColors = @{ "Low"="Success"; "Moderate"="Warning"; "High"="Error"; "Critical"="Error"; "Extreme"="Error" }
    $ThColor = if ($ThreatColors.ContainsKey($Bot.threat)) { $ThreatColors[$Bot.threat] } else { "Text" }
    
    $Indent = " "
    $Lines = @()
    
    # Badges
    $B1 = Get-FormattedBadge -Text $Bot.type -ColorKey "Text"
    $B2 = Get-FormattedBadge -Text $Bot.threat -ColorKey $ThColor
    $Lines += ($Indent + "$B1 $B2")
    
    # Name
    $Lines += ($Indent + $Bot.name)
    
    # Desc
    if ($Bot.description) { $Lines += (Get-WrappedText $Bot.description -Indent $Indent) }
    
    # Weakness
    if ($Bot.weakness) {
        $Lines += "---"
        $Lines += ($Indent + "WEAKNESS:")
        $Lines += (Get-WrappedText $Bot.weakness -Indent $Indent)
    }
    
    # Loot / Drops
    if ($Bot.drops) {
        $Lines += "---"
        $Lines += ($Indent + "DROPS:")
        foreach ($D in $Bot.drops) {
            $Lines += ($Indent + " - $(Get-ItemName $D)")
        }
    }
    
    # Maps
    if ($Bot.maps) {
        $Lines += "---"
        $Lines += ($Indent + "LOCATIONS:")
        foreach ($M in $Bot.maps) {
            $MName = (Get-Culture).TextInfo.ToTitleCase(($M -replace "_", " "))
            $Lines += ($Indent + " - $MName")
        }
    }
    
    Show-Card -Title $null -Content $Lines -ThemeColor $Palette[$ThColor] -BorderColor $Palette[$ThColor]
}

function Show-Project {
    param ($Proj)
    $Indent = " "
    $Lines = @()
    
    if ($Proj.description.en) {
        $Lines += (Get-WrappedText $Proj.description.en -Indent $Indent)
    }
    
    if ($Proj.phases) {
        foreach ($Phase in $Proj.phases) {
            $Lines += "---"
            $PName = if ($Phase.name.en) { $Phase.name.en } else { "Phase $($Phase.phase)" }
            $Lines += ($Indent + "PHASE $($Phase.phase): $PName")
            
            if ($Phase.description.en) {
                $Lines += (Get-WrappedText $Phase.description.en -Indent $Indent)
            }
            
            if ($Phase.requirementItemIds) {
                $Lines += ($Indent + "Requirements:")
                foreach ($Req in $Phase.requirementItemIds) {
                    $Lines += ($Indent + " - $($Req.quantity)x $(Get-ItemName $Req.itemId)")
                }
            }
            if ($Phase.requirementCategories) {
                foreach ($Req in $Phase.requirementCategories) {
                    $Lines += ($Indent + " - $($Sym.Currency) $($Req.valueRequired) in $($Req.category)")
                }
            }
        }
    }
    
    Show-Card -Title $Proj.name.en -Subtitle "Project" -Content $Lines -ThemeColor $Palette.Accent
}

function Show-Skill {
    param ($Skill)
    $Indent = " "
    $Lines = @()
    
    # Badge
    $Lines += ($Indent + (Get-FormattedBadge -Text $Skill.category -ColorKey "Accent"))
    $Lines += ($Indent + $Skill.name.en.ToUpper())
    
    if ($Skill.description.en) {
        $Lines += (Get-WrappedText $Skill.description.en -Indent $Indent)
    }
    
    $Lines += "---"
    if ($Skill.impactedSkill.en) {
        $Lines += ($Indent + "Impacts: $($Skill.impactedSkill.en)")
    }
    if ($Skill.maxPoints) {
        $Lines += ($Indent + "Max Points: $($Skill.maxPoints)")
    }
    
    Show-Card -Title $null -Content $Lines -ThemeColor $Palette.Accent
}

function Show-Events {
    if (-not (Test-Path $PathEvents)) { Write-Ansi "Event data missing." $Palette.Error; return }
    
    $Data = Import-JsonFast $PathEvents
    $Sched = $Data.schedule
    $Types = $Data.eventTypes
    $Maps  = $Data.maps
    
    $TimeNow = [DateTime]::UtcNow
    $Hour = $TimeNow.Hour
    $LocalTime = [DateTime]::Now.ToString("HH:mm")
    
    $W = 62
    
    # Header
    Write-BoxRow $Sym.Box.TL $Sym.Box.H $Sym.Box.TR $Palette.Border $W
    Write-ContentRow -Text "EVENT SCHEDULE" -TextColor $Palette.Accent -BorderColor $Palette.Border -Align "Center" $W
    Write-BoxRow $Sym.Box.L $Sym.Box.H $Sym.Box.R $Palette.Border $W
    
    # Active Events
    Write-ContentRow -Text " ACTIVE NOW ($LocalTime)" -TextColor $Palette.Success -BorderColor $Palette.Border $W
    Write-BoxRow $Sym.Box.L $Sym.Box.H $Sym.Box.R $Palette.Border $W
    
    foreach ($MapKey in $Sched.PSObject.Properties.Name) {
        $MapName = if ($Maps.$MapKey.displayName) { $Maps.$MapKey.displayName } else { $MapKey }
        $MajorKey = $Sched.$MapKey.major."$Hour"
        $MinorKey = $Sched.$MapKey.minor."$Hour"
        
        if ($MajorKey -or $MinorKey) {
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
    
    # Upcoming
    Write-ContentRow -Text " UPCOMING SCHEDULE" -TextColor $Palette.Accent -BorderColor $Palette.Border $W
    
    $Sep = "$($Sym.Box.L)$([string]::new($Sym.Box.H, 7))$($Sym.Box.C)$([string]::new($Sym.Box.H, 30))$($Sym.Box.C)$([string]::new($Sym.Box.H, 21))$($Sym.Box.R)"
    Write-Ansi $Sep $Palette.Border
    
    $List = @()
    foreach ($EKey in $Types.PSObject.Properties.Name) {
        if ($EKey -eq "none" -or $Types.$EKey.disabled) { continue }
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
    
    foreach ($Ev in $List) {
        $TStr = if (($Ev.Time - $TimeNow).TotalHours -lt 1) { " NOW " } else { $Ev.Time.ToLocalTime().ToString("HH:mm") }
        $EvColor = if ($Ev.Cat -eq "major") { $Palette.Text } else { $Palette.Subtext }
        
        Write-Ansi $Sym.Box.V $Palette.Border -NoNewline
        Write-Ansi $TStr.PadRight(7) $Palette.Accent -NoNewline
        Write-Ansi $Sym.Box.V $Palette.Border -NoNewline
        
        $N = $Ev.Name; if ($N.Length -gt 30) { $N = $N.Substring(0, 27) + "..." }
        Write-Ansi $N.PadRight(30) $EvColor -NoNewline
        Write-Ansi $Sym.Box.V $Palette.Border -NoNewline
        
        $M = $Ev.Map; if ($M.Length -gt 21) { $M = $M.Substring(0, 18) + "..." }
        Write-Ansi $M.PadRight(21) $Palette.Subtext -NoNewline
        Write-Ansi $Sym.Box.V $Palette.Border
        
        if ($Ev -ne $List[-1]) { Write-Ansi $Sep $Palette.Border }
    }
    
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
Initialize-Data

$Results = @()

# 1. Search Items
foreach ($Item in $Global:Data.Items.Values) {
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

# 4. Search Bots
foreach ($Bot in $Global:Data.Bots) {
    if ($Bot.name -like "*$Query*") {
        $Results += [PSCustomObject]@{ Type="Bot"; Name=$Bot.name; Data=$Bot }
    }
}

# 5. Search Projects
foreach ($Proj in $Global:Data.Projects) {
    if ($Proj.name.en -like "*$Query*") {
        $Results += [PSCustomObject]@{ Type="Project"; Name=$Proj.name.en; Data=$Proj }
    }
}

# 6. Search Skills
foreach ($Skill in $Global:Data.Skills) {
    if ($Skill.name.en -like "*$Query*") {
        $Results += [PSCustomObject]@{ Type="Skill"; Name=$Skill.name.en; Data=$Skill }
    }
}

# Result Handling
if ($Results.Count -eq 0) {
    Write-Ansi "No results found." $Palette.Error
} elseif ($Results.Count -eq 1) {
    $T = $Results[0]
    switch ($T.Type) {
        "Item"    { Show-Item $T.Data }
        "Bot"     { Show-Bot $T.Data }
        "Project" { Show-Project $T.Data }
        "Skill"   { Show-Skill $T.Data }
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
} else {
    # Check for Auto-Select Argument
    if ($SelectIndex -ge 0 -and $SelectIndex -lt $Results.Count) {
        $Idx = $SelectIndex
    } else {
        Write-Ansi "SEARCH RESULTS" $Palette.Accent
        for ($i=0; $i -lt $Results.Count; $i++) {
            if ($i -ge 20) { Write-Ansi "... and more" $Palette.Subtext; break }
            Write-Ansi " [$i] " $Palette.Accent -NoNewline
            Write-Ansi "$($Results[$i].Name) " $Palette.Text -NoNewline
            Write-Ansi "($($Results[$i].Type))" $Palette.Subtext
        }
        
        Write-Ansi "`nSelect (0-$($Results.Count - 1)): " $Palette.Accent -NoNewline
        try {
            $Host.UI.RawUI.FlushInputBuffer()
            $Key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            if ($Key.Character -match "[0-9]") {
                $Idx = [int][string]$Key.Character
                Write-Host $Idx
            }
        } catch {}
    }

    if ($null -ne $Idx -and $Idx -lt $Results.Count) {
        $T = $Results[$Idx]
        switch ($T.Type) {
            "Item"    { Show-Item $T.Data }
            "Bot"     { Show-Bot $T.Data }
            "Project" { Show-Project $T.Data }
            "Skill"   { Show-Skill $T.Data }
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
