import pandas as pd
import unicodedata

def normalize_text(s: str) -> str:
    """Normalisiert einen String für robuste Namensvergleiche."""
    if pd.isna(s):
        return ''
    s = unicodedata.normalize('NFKD', str(s))
    s = ''.join(c for c in s if not unicodedata.combining(c))
    return s.strip().lower()

def finde_freie_freiwillige(volunteer_csv, jobs_csv, output_csv="freiwillige_ohne_schicht.csv"):
    # Volunteer-Datei laden
    volunteers = pd.read_csv(volunteer_csv, sep=';', encoding='utf-8-sig')
    volunteers.columns = [col.strip().lower().lstrip('\ufeff') for col in volunteers.columns]

    # Job-Datei laden
    jobs = pd.read_csv(jobs_csv, sep=';', encoding='cp1252')
    jobs.columns = [col.strip() for col in jobs.columns]

    # Namen normalisieren
    volunteers["name_clean"] = (volunteers["vorname"].astype(str) + " " + volunteers["nachname"].astype(str)).apply(normalize_text)
    jobs["name_clean"] = jobs["Person"].astype(str).apply(normalize_text)

    # Personen aus Volunteer-Liste, die nicht im Job-Plan vorkommen
    ohne_schicht = volunteers[~volunteers["name_clean"].isin(jobs["name_clean"])].copy()

    # Ausgabespalten vorbereiten
    ohne_schicht["Name"] = ohne_schicht["vorname"].str.strip() + " " + ohne_schicht["nachname"].str.strip()
    output = ohne_schicht[["Name", "team"]].rename(columns={"team": "Team"})

    # Datei speichern
    output.to_csv(output_csv, sep=';', index=False)
    print(f"✅ Es wurden {len(output)} Personen ohne Schicht gefunden.")
    print(f"📄 Ergebnis gespeichert in: {output_csv}")

# Beispielaufruf
if __name__ == "__main__":
    finde_freie_freiwillige(
        volunteer_csv="Essen_auswertung/202507292051volunteer-people.csv", #Excel-Download aller Crew Leute mit den spalten: vorname, nachname, team (Team nur von Laura auszufüllen) 
        jobs_csv="2025-07-29 20_56_50jobs.csv" #Download aller Jobs 
    )
