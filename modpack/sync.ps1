# Allinea l'istanza PolyMC al modpack: scarica da Modrinth le mod mancanti o cambiate
# e cancella dalla cartella mods i jar che non sono in mods.json. Le config non si toccano.
# Uso: powershell -ExecutionPolicy Bypass -File sync.ps1 <cartella istanza>
param([Parameter(Mandatory)][string]$Instance)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$modsDir = Join-Path $Instance '.minecraft\mods'
New-Item -ItemType Directory -Force $modsDir | Out-Null
Copy-Item (Join-Path $PSScriptRoot 'mmc-pack.json') $Instance -Force
# instance.cfg solo la prima volta: PolyMC ci salva le impostazioni del giocatore
if (!(Test-Path (Join-Path $Instance 'instance.cfg'))) {
    Copy-Item (Join-Path $PSScriptRoot 'instance.cfg') $Instance
}

$mods = Get-Content (Join-Path $PSScriptRoot 'mods.json') -Raw | ConvertFrom-Json
foreach ($m in $mods) {
    $dest = Join-Path $modsDir $m.name
    if ((Test-Path $dest) -and (Get-FileHash $dest -Algorithm SHA1).Hash -eq $m.sha1) { continue }
    Write-Host "  Scarico $($m.name)"
    Invoke-WebRequest -UseBasicParsing $m.url -OutFile "$dest.tmp"
    if ((Get-FileHash "$dest.tmp" -Algorithm SHA1).Hash -ne $m.sha1) {
        Remove-Item "$dest.tmp"
        throw "sha1 diverso da quello atteso per $($m.name)"
    }
    Move-Item -Force "$dest.tmp" $dest
}

$names = $mods | ForEach-Object { $_.name }
Get-ChildItem $modsDir -File -Filter *.jar | Where-Object { $names -notcontains $_.Name } | ForEach-Object {
    Write-Host "  Rimuovo $($_.Name)"
    Remove-Item $_.FullName
}
