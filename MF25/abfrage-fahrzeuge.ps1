# ----------------------------------
# Konfiguration
# ----------------------------------
$baseUrl = "https://macherfestival.festiwa.re"
$clientId = 2
$clientSecret = "NCe0Zmn1uM1ET1sZW0VmTR9LZyJWyDHWxRTX62oR"
$username = "api4@festiware.eu"
$password = "Ns2pqmFzxod7eZ2q"
$groupTypeId = 39     # Fahrzeuge
$projectId = 1        # Macher Festival 2025
$csvExportPath = ".\fahrzeuge.csv"

# ----------------------------------
# Token holen
# ----------------------------------
Write-Host "🔐 Token wird angefragt..."

try {
    $tokenResponse = Invoke-RestMethod -Uri "$baseUrl/oauth/token" -Method Post -Body @{
        grant_type    = "password"
        client_id     = $clientId
        client_secret = $clientSecret
        username      = $username
        password      = $password
        scope         = ""
    } -ContentType "application/x-www-form-urlencoded"
} catch {
    Write-Error "Fehler beim Abrufen des Tokens: $_"  ,.l 
    exit 1
}

$accessToken = $tokenResponse.access_token

if (-not $accessToken) {
    Write-Error "❌ Kein Access Token erhalten. Antwort:"
    $tokenResponse | ConvertTo-Json -Depth 10
    exit 1
}

Write-Host "✅ Token erfolgreich erhalten.`n"

# ----------------------------------
# Fahrzeugdaten abrufen
# ----------------------------------
$uri = "$baseUrl/api/v1/applications/$groupTypeId/$projectId"
Write-Host "📡 Fahrzeugdaten werden geladen von: $uri"

try {
    $response = Invoke-RestMethod -Uri $uri -Headers @{
        Authorization = "Bearer $accessToken"
        Accept        = "application/json"
    } -Method Get
} catch {
    Write-Error "Fehler beim Abrufen der Fahrzeugdaten: $_"
    exit 1
}

# ----------------------------------
# Ausgabe und Export
# ----------------------------------
if ($response -and $response.Count -gt 0) {
    Write-Host "`n🚗 $($response.Count) Fahrzeuge gefunden:`n"
    $response | Format-Table -AutoSize

    $response | Export-Csv -Path $csvExportPath -NoTypeInformation -Encoding UTF8
    Write-Host "`n💾 Fahrzeugdaten exportiert nach: $csvExportPath"
} else {
    Write-Warning "⚠️ Keine Fahrzeuge erhalten oder unerwartetes Antwortformat:"
    $response | ConvertTo-Json -Depth 10
}
