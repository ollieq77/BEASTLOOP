
$files = Get-ChildItem -File -Filter "*.ogg"

foreach ($file in $files) {
    $name = $file.BaseName

    if ($name -match "^(.+?)_(Inst|Voices)$") {
        $song = $Matches[1]
        $type = $Matches[2]
    }
    else {
        $song = $name
        $type = $null
    }

    $folder = $song.ToLower() -replace "_", "-" -replace " ", "-"
    $destination = Join-Path $PWD $folder

    New-Item -ItemType Directory -Path $destination -Force | Out-Null

    $newName = if ($type) { "$type.ogg" } else { "$name.ogg" }

    Move-Item $file.FullName (Join-Path $destination $newName)
}
