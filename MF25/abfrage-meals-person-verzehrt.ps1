
# ========================================
# FESTIWARE EXPORT MIT VERZEHR-INFO
# ========================================
$baseUrl = "https://macherfestival.festiwa.re"
$clientId = 2
$clientSecret = "NCe0Zmn1uM1ET1sZW0VmTR9LZyJWyDHWxRTX62oR"
$username = "api4@festiware.eu"
$password = "Ns2pqmFzxod7eZ2q"
$projectId = 1
$csvExportPath = ".\meal-details-with-consumption.csv"

Write-Host "🔐 Hole Access Token..."
$tokenResponse = Invoke-RestMethod -Uri "$baseUrl/oauth/token" -Method Post -Body @{
    grant_type    = "password"
    client_id     = $clientId
    client_secret = $clientSecret
    username      = $username
    password      = $password
    scope         = ""
} -ContentType "application/x-www-form-urlencoded"
$accessToken = $tokenResponse.access_token
Write-Host "✅ Token erhalten.`n"

function Get-Person {
    param([string]$PersonId)
    $uri = "$baseUrl/api/v1/people/$PersonId"
    $maxRetries = 10
    $retryDelay = 60
    for ($try = 1; $try -le $maxRetries; $try++) {
        try {
            return Invoke-RestMethod -Uri $uri -Headers @{
                Authorization = "Bearer $accessToken"
                Accept = "application/json"
            } -Method Get
        } catch {
            $status = $_.Exception.Response.StatusCode.Value__
            if ($status -eq 429) {
                Write-Host ("⏳ Rate Limit bei Person {0} – Warte {1}s (Versuch {2}/{3})" -f $PersonId, $retryDelay, $try, $maxRetries) -ForegroundColor Yellow
                Start-Sleep -Seconds $retryDelay
            } else {
                Write-Host ("❌ Fehler bei Person {0}: {1}" -f $PersonId, $_.Exception.Message) -ForegroundColor Red
                return $null
            }
        }
    }
    Write-Host ("❌ Abbruch: Zu viele Versuche für Person $PersonId") -ForegroundColor Red
    return $null
}

function Get-MealDetail {
    param([int]$MealId)
    $uri = "$baseUrl/api/v1/meals/$projectId/$MealId"
    $maxRetries = 10
    $retryDelay = 60
    for ($try = 1; $try -le $maxRetries; $try++) {
        try {
            return Invoke-RestMethod -Uri $uri -Headers @{
                Authorization = "Bearer $accessToken"
                Accept = "application/json"
            } -Method Get
        } catch {
            $status = $_.Exception.Response.StatusCode.Value__
            if ($status -eq 429) {
                Write-Host ("⏳ Rate Limit bei Mahlzeit {0} – Warte {1}s (Versuch {2}/{3})" -f $MealId, $retryDelay, $try, $maxRetries) -ForegroundColor Yellow
                Start-Sleep -Seconds $retryDelay
            } else {
                Write-Host ("❌ Fehler bei Mahlzeit {0}: {1}" -f $MealId, $_.Exception.Message) -ForegroundColor Red
                return $null
            }
        }
    }
    Write-Host ("❌ Abbruch: Zu viele Versuche für Mahlzeit $MealId") -ForegroundColor Red
    return $null
}

Write-Host "📡 Lade alle Mahlzeiten..."
$mealList = Invoke-RestMethod -Uri "$baseUrl/api/v1/meals/$projectId" -Headers @{
    Authorization = "Bearer $accessToken"
    Accept = "application/json"
} -Method Get

$exportData = @()
$processedPersons = @{}

foreach ($meal in $mealList) {
    $mealId = $meal.id
    $mealName = $meal.display_name
    $servedFrom = $meal.served_from
    $servedUntil = $meal.served_until

    Write-Host "`n🍽 Mahlzeit: $mealName (ID: $mealId)"
    $mealDetail = Get-MealDetail -MealId $mealId

    if ($mealDetail -and $mealDetail.meal_orders.Count -gt 0) {
        Write-Host "➡️  $($mealDetail.meal_orders.Count) Buchungen..."

        foreach ($booking in $mealDetail.meal_orders) {
            $personId = $booking.person_id

            if (-not $processedPersons.ContainsKey($personId)) {
                $person = Get-Person -PersonId $personId
                Start-Sleep -Milliseconds 300
                $processedPersons[$personId] = $person
            } else {
                $person = $processedPersons[$personId]
            }

            if ($person) {
                $exportData += [PSCustomObject]@{
                    Mahlzeit            = $mealName
                    Datum_Von           = $servedFrom
                    Datum_Bis           = $servedUntil
                    Gebucht_Am          = $booking.ordered_at
                    Verzehrt_Am         = $booking.consumed_at
                    Nachschlag_Am       = $booking.second_consumed_at
                    Portionen_Verzehrt  = $booking.amount_consumed
                    Verzehrt_Confirmed  = $booking.is_consumed
                    Vorname             = $person.data.firstname
                    Nachname            = $person.data.name
                    EMail               = $person.data.email
                    Vegetarisch         = $person.data.vegetarisch
                    Allergien           = $person.data.unvertraglichkeiten
                    Kommentar           = $booking.comment
                    PersonID            = $person.id
                }

                Write-Host ("  👤 {0} {1} | {2} | Verzehrt: {3}" -f $person.data.firstname, $person.data.name, $person.data.vegetarisch, $booking.consumed_at)
            }
        }
    } else {
        Write-Host "⚠️  Keine Buchungen"
    }
}

$exportData | Export-Csv -Path $csvExportPath -NoTypeInformation -Encoding UTF8
Write-Host "`n✅ Export abgeschlossen: $csvExportPath"
