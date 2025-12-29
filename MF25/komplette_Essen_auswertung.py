import pandas as pd
import os

def main():
    # --- KONFIGURATION ---
    # Name der Basisdatei und der Name der ID-Spalte darin
    base_filename = "Originale Daten.csv"
    base_id_col = "PersonID" # Laut deiner Datei heißt die letzte Spalte so

    # Dictionary der Vergleichsdateien: "Dateiname": "Name der ID-Spalte"
    # Hinweis: In 'volunteer-people' heißt die Spalte 'Ident', in den anderen 'ID'
    compare_files = {
        "202511230855partner-people.csv": "ID",
        "202511230859visitor-people.csv": "ID",
        "202511230900artist-people.csv": "ID",
        "202511230854service-people.csv": "ID",
        "202511230854volunteer-people.csv": "Ident"
    }
    
    output_filename = "Originale_Daten_Erweitert.csv"
    # ---------------------

    print(f"Lese Basisdatei: {base_filename} ...")
    try:
        # Trennzeichen ist Semikolon in der Basisdatei
        df_base = pd.read_csv(base_filename, sep=";", dtype={base_id_col: str})
        # Leerzeichen entfernen, um Match-Probleme zu vermeiden
        df_base[base_id_col] = df_base[base_id_col].str.strip()
    except FileNotFoundError:
        print(f"FEHLER: Die Datei '{base_filename}' wurde nicht gefunden.")
        return

    # Wir laden alle IDs der Vergleichsdateien in Sets für schnellen Zugriff
    lookup_data = {}
    
    print("Lese Vergleichsdateien ...")
    for fname, id_col in compare_files.items():
        if os.path.exists(fname):
            try:
                # Trennzeichen ist Komma in den anderen Dateien
                df_temp = pd.read_csv(fname, sep=",", dtype={id_col: str})
                # Erstelle ein Set aller IDs in dieser Datei (bereinigt um Leerzeichen)
                ids = set(df_temp[id_col].dropna().str.strip())
                lookup_data[fname] = ids
                print(f"  - {fname}: {len(ids)} IDs geladen.")
            except Exception as e:
                print(f"  - WARNUNG: Fehler beim Lesen von {fname}: {e}")
        else:
            print(f"  - WARNUNG: Datei nicht gefunden: {fname}")

    # Funktion zum Finden der Matches für eine einzelne ID
    def find_sources(person_id):
        matches = []
        if pd.isna(person_id) or person_id == "":
            return matches
            
        for fname, id_set in lookup_data.items():
            if person_id in id_set:
                matches.append(fname)
        return matches

    print("Führe Matching durch ...")
    # Wir wenden die Suchfunktion auf jede Zeile an
    # Das Ergebnis ist eine Liste von Dateinamen pro Zeile
    match_results = df_base[base_id_col].apply(find_sources)

    # Wir schauen, wie viele Spalten wir maximal brauchen (falls ID in 2 oder 3 Dateien ist)
    max_matches = match_results.apply(len).max()
    if pd.isna(max_matches): 
        max_matches = 0
    
    print(f"Maximale Anzahl gefundener Dateien pro ID: {max_matches}")

    # Neue Spalten erzeugen
    for i in range(max_matches):
        col_name = f"Gefunden_In_Datei_{i+1}"
        # Schreibt den i-ten Treffer in die Spalte, falls vorhanden
        df_base[col_name] = match_results.apply(lambda x: x[i] if i < len(x) else None)

    # Speichern
    print(f"Speichere Ergebnis in: {output_filename}")
    df_base.to_csv(output_filename, sep=";", index=False)
    print("Fertig!")

if __name__ == "__main__":
    main()