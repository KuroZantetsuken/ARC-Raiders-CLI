param (
    [string]$Query
)

# --- Configuration ---
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$DataItemsDir = Join-Path $RepoRoot "data\items"
$DataQuestsDir = Join-Path $RepoRoot "arcraiders-data\quests"
$DataHideoutDir = Join-Path $RepoRoot "arcraiders-data\hideout"
$DataEventsFile = Join-Path $RepoRoot "arcraiders-data\map-events\map-events.json"

# --- Helper Functions ---

function Get-JsonContent {
    param ($Path)
    try {
        Get-Content -Path $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        return $null
    }
}

function Write-Color {
    param ($Text, $Color="White", $NoNewline=$false)
    if ($NoNewline) {
        Write-Host $Text -ForegroundColor $Color -NoNewline
    } else {
        Write-Host $Text -ForegroundColor $Color
    }
}

# --- Event Logic ---

function Show-Events {
    if (-not (Test-Path $DataEventsFile)) {
        Write-Color "Event data not found at $DataEventsFile" "Red"
        return
    }
    
    $EventsData = Get-JsonContent $DataEventsFile
    $Schedule = $EventsData.schedule
    $EventTypes = $EventsData.eventTypes
    $Maps = $EventsData.maps
    
    $UtcNow = [DateTime]::UtcNow
    $LocalNow = [DateTime]::Now
    $CurrentUtcHour = $UtcNow.Hour
    
    Write-Color "`n=== ARC Raiders Event Schedule ===" "Cyan"
    Write-Color "Current Time: $($LocalNow.ToString('g'))" "Gray"
    
    foreach ($MapKey in $Schedule.PSObject.Properties.Name) {
        $MapName = if ($Maps.$MapKey.displayName) { $Maps.$MapKey.displayName } else { $MapKey }
        $MapSchedule = $Schedule.$MapKey
        
        Write-Color "`n$MapName" "Yellow"
        
        foreach ($Type in @("major", "minor")) {
            if (-not $MapSchedule.$Type) { continue }
            
            $Events = $MapSchedule.$Type
            $ActiveEventId = $null
            $NextEventId = $null
            $NextEventTime = $null
            
            # Find Active (starts at CurrentUtcHour)
            if ($Events."$CurrentUtcHour") {
                $ActiveEventId = $Events."$CurrentUtcHour"
            }
            
            # Find Next
            for ($h = 1; $h -le 24; $h++) {
                $CheckHour = ($CurrentUtcHour + $h) % 24
                # CheckHour needs to be string key
                if ($Events."$CheckHour") {
                    $NextEventId = $Events."$CheckHour"
                    
                    # Calculate local time
                    $FutureUtc = $UtcNow.AddHours($h)
                    # We want the exact hour of that future time
                    $NextTimeUtc = Get-Date -Date $FutureUtc -Hour $CheckHour -Minute 0 -Second 0
                    
                    $NextEventTime = $NextTimeUtc.ToLocalTime()
                    break
                }
            }
            
            # Display Active
            if ($ActiveEventId) {
                $EventName = $EventTypes.$ActiveEventId.displayName
                Write-Color "  [Active $Type]: $EventName" "Green"
            } else {
                Write-Color "  [Active $Type]: None" "DarkGray"
            }
            
            # Display Next
            if ($NextEventId) {
                $EventName = $EventTypes.$NextEventId.displayName
                $TimeStr = $NextEventTime.ToString("HH:mm")
                Write-Color "  [Next $Type]:   $EventName at $TimeStr" "White"
            }
        }
    }
}

# --- Display Handlers ---

function Show-Item {
    param ($Item)
    Write-Color "`n=== Item: $($Item.name.en) ===" "Cyan"
    Write-Color "ID: $($Item.id)" "DarkGray"
    Write-Color "Type: $($Item.type)" "Gray"
    if ($Item.rarity) { Write-Color "Rarity: $($Item.rarity)" "White" }
    
    if ($null -ne $Item.stashSavings) {
        $Savings = $Item.stashSavings
        $Color = if ($Savings -gt 0) { "Green" } else { "Red" }
        Write-Color "Stash Savings: $( "{0:N4}" -f $Savings ) slots" $Color
    }
    
    if ($Item.recipe) {
        Write-Color "Recipe:" "Yellow"
        $Item.recipe.PSObject.Properties | ForEach-Object {
            Write-Color "  - $($_.Name): $($_.Value)" "White"
        }
    }
    
    if ($Item.description.en) {
        Write-Color "`n$($Item.description.en)" "Gray"
    }
}

function Show-Quest {
    param ($Quest)
    Write-Color "`n=== Quest: $($Quest.name.en) ===" "Cyan"
    Write-Color "ID: $($Quest.id)" "DarkGray"
    Write-Color "Trader: $($Quest.trader)" "Yellow"
    
    if ($Quest.description.en) {
        Write-Color "`n$($Quest.description.en)" "Gray"
    }
    
    if ($Quest.objectives) {
        Write-Color "`nObjectives:" "White"
        foreach ($Obj in $Quest.objectives) {
            if ($Obj.en) {
                Write-Color "  [ ] $($Obj.en)" "White"
            }
        }
    }
    
    if ($Quest.rewardItemIds) {
        Write-Color "`nRewards:" "Green"
        foreach ($Reward in $Quest.rewardItemIds) {
            Write-Color "  - $($Reward.quantity)x $($Reward.itemId)" "Green"
        }
    }
}

function Show-Hideout {
    param ($Hideout)
    Write-Color "`n=== Hideout: $($Hideout.name.en) ===" "Cyan"
    Write-Color "ID: $($Hideout.id)" "DarkGray"
    Write-Color "Max Level: $($Hideout.maxLevel)" "Gray"
    
    if ($Hideout.levels) {
        Write-Color "`nUpgrades:" "White"
        foreach ($Lvl in $Hideout.levels) {
            if ($Lvl.requirementItemIds.Count -gt 0) {
                Write-Color "  Level $($Lvl.level):" "Yellow"
                foreach ($Req in $Lvl.requirementItemIds) {
                    Write-Color "    - $($Req.quantity)x $($Req.itemId)" "White"
                }
            } else {
                Write-Color "  Level $($Lvl.level): Free / Base" "DarkGray"
            }
        }
    }
}

# --- Main Search ---

if ([string]::IsNullOrWhiteSpace($Query)) {
    Write-Color "Usage: ARCSearch <Query>" "Red"
    Write-Color "Examples:" "Gray"
    Write-Color "  ARCSearch herbal" "Gray"
    Write-Color "  ARCSearch events" "Gray"
    exit
}

if ($Query -eq "events") {
    Show-Events
    exit
}

Write-Color "Searching for '$Query'..." "DarkGray"

$Results = @()

# 1. Search Items
$ItemFiles = Get-ChildItem $DataItemsDir -Filter "*.json"
foreach ($File in $ItemFiles) {
    try {
        $Json = Get-JsonContent $File.FullName
        if ($null -eq $Json) { continue }
        
        if ($Json.id -like "*$Query*" -or $Json.name.en -like "*$Query*") {
            $Results += [PSCustomObject]@{
                Type = "Item"
                Name = $Json.name.en
                ID = $Json.id
                Data = $Json
            }
        }
    } catch {}
}

# 2. Search Quests
if (Test-Path $DataQuestsDir) {
    $QuestFiles = Get-ChildItem $DataQuestsDir -Filter "*.json"
    foreach ($File in $QuestFiles) {
        try {
            $Json = Get-JsonContent $File.FullName
            if ($null -eq $Json) { continue }
            
            if ($Json.name.en -like "*$Query*") {
                $Results += [PSCustomObject]@{
                    Type = "Quest"
                    Name = $Json.name.en
                    ID = $Json.id
                    Data = $Json
                }
            }
        } catch {}
    }
}

# 3. Search Hideouts
if (Test-Path $DataHideoutDir) {
    $HideoutFiles = Get-ChildItem $DataHideoutDir -Filter "*.json"
    foreach ($File in $HideoutFiles) {
        try {
            $Json = Get-JsonContent $File.FullName
            if ($null -eq $Json) { continue }
            
            if ($Json.name.en -like "*$Query*" -or $Json.id -like "*$Query*") {
                $Results += [PSCustomObject]@{
                    Type = "Hideout"
                    Name = $Json.name.en
                    ID = $Json.id
                    Data = $Json
                }
            }
        } catch {}
    }
}

# --- Selection Logic ---

if ($Results.Count -eq 0) {
    Write-Color "No results found." "Red"
} elseif ($Results.Count -eq 1) {
    $Target = $Results[0]
    if ($Target.Type -eq "Item") { Show-Item $Target.Data }
    elseif ($Target.Type -eq "Quest") { Show-Quest $Target.Data }
    elseif ($Target.Type -eq "Hideout") { Show-Hideout $Target.Data }
} else {
    # Multiple results
    Write-Color "Multiple results found:" "Cyan"
    $Index = 0
    foreach ($Res in $Results) {
        if ($Index -gt 9) { break }
        Write-Color "[$Index] $($Res.Name) ($($Res.Type))" "White"
        $Index++
    }
    
    if ($Results.Count -gt 10) {
        Write-Color "... and more." "DarkGray"
    }
    
    Write-Color "`nSelect (0-$($Index-1)): " "Yellow" -NoNewline
    
    # Interactive Key Press
    try {
        $Host.UI.RawUI.FlushInputBuffer()
        $Key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        $Char = [string]$Key.Character
        if ($Char -match "[0-9]") {
            $Selection = [int]$Char
            Write-Host $Selection # Echo the number
            
            if ($Selection -lt $Index) {
                $Target = $Results[$Selection]
                if ($Target.Type -eq "Item") { Show-Item $Target.Data }
                elseif ($Target.Type -eq "Quest") { Show-Quest $Target.Data }
                elseif ($Target.Type -eq "Hideout") { Show-Hideout $Target.Data }
            } else {
                Write-Color "`nInvalid selection." "Red"
            }
        } else {
            Write-Color "`nCancelled." "Red"
        }
    } catch {
        Write-Host "`nInteractive mode not supported or error reading key."
    }
}
