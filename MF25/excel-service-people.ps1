<#
.SYNOPSIS
  Splittet service-people.xlsx nach company, nimmt nur firstname,name,zugangsbereich_bandchen,pass_benotigt,sonder_parkberechtigungen,company 
  (fügt fehlende der ersten fünf als leere Spalten hinzu) und schreibt pro Firma eine eigene XLSX.

.PARAMETER InputFile
  Pfad zur Quelldatei.

.PARAMETER OutputDir
  Zielordner für die Ausgaben.
#>

param (
    [Parameter(Mandatory=$true)]
    [string]$InputFile,

    [Parameter(Mandatory=$true)]
    [string]$OutputDir
)

# Modul sicherstellen
if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
    Install-Module ImportExcel -Scope CurrentUser -Force -AllowClobber
}
Import-Module ImportExcel

# Pfade prüfen / erstellen
if (-not (Test-Path $InputFile)) {
    Write-Error "Input-Datei nicht gefunden: $InputFile"
    exit 1
}
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

# Einlesen
$data = Import-Excel -Path $InputFile -ErrorAction Stop
if (-not $data -or $data.Count -eq 0) {
    Write-Error "Keine Daten oder Einlesen fehlgeschlagen."
    exit 1
}

# Gewünschte Basis-Spalten sicherstellen
$needed = @("firstname","name","zugangsbereich_bandchen","pass_benotigt","sonder_parkberechtigungen")
foreach ($col in $needed) {
    if (-not ($data | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object { $_ -eq $col })) {
        # fehlende Spalte hinzufügen (leer)
        $data | ForEach-Object { $_ | Add-Member -NotePropertyName $col -NotePropertyValue "" -Force }
    }
}

# company ableiten & Auswahl
$processed = $data | Select-Object `
    firstname,
    name,
    zugangsbereich_bandchen,
    pass_benotigt,
    sonder_parkberechtigungen,
    @{Name='company'; Expression={
        if ($_.applicationsAsOwnerAsString -and $_.applicationsAsOwnerAsString -ne "--") {
            $_.applicationsAsOwnerAsString.Trim()
        } elseif ($_.applicationsAsMemberAsString -and $_.applicationsAsMemberAsString -ne "--") {
            $_.applicationsAsMemberAsString.Trim()
        } else {
            "Sonstiges"
        }
    }}

# Helper: sicherer Dateiname
function Safe-Name($name) {
    return ($name -replace '[\\\/:\*\?"<>\|]', '_')
}

# Splitten und exportieren
foreach ($group in $processed | Group-Object -Property company) {
    $company = $group.Name
    $safe = if ($company -eq "Sonstiges") { "Sonstiges" } else { Safe-Name $company }
    $outFile = Join-Path $OutputDir "company_$safe.xlsx"

    if (Test-Path $outFile) { Remove-Item $outFile -ErrorAction SilentlyContinue }

    try {
        $group.Group | Export-Excel -Path $outFile -AutoSize
        Write-Host "Erstellt: $outFile"
    } catch {
        Write-Warning "Export für '$company' fehlgeschlagen: $_"
    }
}
