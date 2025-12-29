import pandas as pd
import fitz
from collections import Counter
import unicodedata
import re

def normalize_text(s: str) -> str:
    # Für robusteren Vergleich (Umlaute angleichen, Kleinbuchstaben)
    s = unicodedata.normalize('NFKD', s)
    s = ''.join(ch for ch in s if not unicodedata.combining(ch))
    return s.lower()

def check_names_in_pdf(pdf_path, csv_path, output_dir="./"):
    # PDF-Text extrahieren & normalisieren (Zeilenumbrüche raus, Mehrfach‑Spaces vereinheitlichen)
    with fitz.open(pdf_path) as doc:
        pdf_text = " ".join(page.get_text() for page in doc)
    pdf_text_clean = re.sub(r'\s+', ' ', pdf_text)
    pdf_text_norm  = normalize_text(pdf_text_clean)

    # CSV laden (mit BOM-Schutz)
    df = pd.read_csv(csv_path, sep=";", encoding="utf-8-sig")

    # Spaltennamen normalisieren & BOM entfernen
    df.columns = [c.strip().lower().lstrip('\ufeff') for c in df.columns]

    required = {"vorname", "nachname"}
    if not required.issubset(df.columns):
        raise ValueError(f"Erwartete Spalten fehlen. Gefunden: {df.columns}")

    fehlende_personen = []
    fehlende_teams = []

    for _, row in df.iterrows():
        vor = str(row['vorname']).strip()
        nach = str(row['nachname']).strip()
        if not vor and not nach:
            continue
        full_name = f"{vor} {nach}".strip()

        # Normalisierte Variante für Matching
        full_name_norm = normalize_text(full_name)
        # Einfache Wortgrenzenprüfung (nach Normalisierung)
        found = full_name_norm in pdf_text_norm

        team = "Unbekannt"
        if 'team' in df.columns and pd.notna(row['team']) and str(row['team']).strip():
            team = str(row['team']).strip()

        if not found:
            fehlende_personen.append({"Name": full_name, "Team": team})
            fehlende_teams.append(team)

    team_counter = Counter(fehlende_teams)
    fehlende_teams_df = pd.DataFrame(
        [{"Team": t, "Anzahl fehlender Personen": c} for t, c in sorted(team_counter.items())]
    )
    fehlende_personen_df = pd.DataFrame(fehlende_personen)

    fehlende_teams_df.to_csv(f"{output_dir}/fehlende_teams.csv", index=False, sep=";")
    fehlende_personen_df.to_csv(f"{output_dir}/fehlende_personen.csv", index=False, sep=";")

    return fehlende_personen_df, fehlende_teams_df


check_names_in_pdf(
    "Essen_auswertung/2025-07-18_220937meals-Macher25.pdf", #PDF download aller Mahlzeiten
    "Essen_auswertung/202507182210volunteer-people.csv", #Dowload Excel der CREW 
    output_dir="Essen_auswertung"
)
