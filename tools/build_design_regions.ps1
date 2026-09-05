$source = Join-Path $PSScriptRoot '..\..\vietnam-provinces-game.json'
$target = Join-Path $PSScriptRoot '..\data\design_regions.json'
$items = Get-Content -Raw $source | ConvertFrom-Json
$regions = @()
$index = 0
foreach ($item in $items) {
    $faction = if ([double]$item.center_lat -ge 17.0) { 'north' } else { 'south' }
    $terrain = if ([double]$item.center_lat -ge 17.0) { 'highland' } elseif ([double]$item.center_lat -le 11.5) { 'delta' } else { 'coast' }
    $rings = @()
    foreach ($ring in $item.coordinates) {
        $points = @()
        foreach ($point in $ring) { $points += ,@([double]$point[1], [double]$point[0]) }
        $rings += ,$points
    }
    $regions += [ordered]@{ id = "r$index"; name = [string]$item.name_vn; source_id = [string]$item.id; lat = [double]$item.center_lat; lon = [double]$item.center_lng; faction = $faction; terrain = $terrain; insurgency = if ($faction -eq 'north') { 8 } else { 28 }; rings = $rings }
    $index++
}
$payload = [ordered]@{ schema = 1; disclaimer = 'Design regions derived from public outlines; not historical 1965 administrative boundaries'; regionCount = $regions.Count; regions = $regions }
$payload | ConvertTo-Json -Depth 10 -Compress | Set-Content -Encoding UTF8 $target
Write-Output "Wrote $($regions.Count) design regions to $target"
