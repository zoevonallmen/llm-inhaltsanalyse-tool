source("R/instructor.R")

# Test einfache Prompt-Generierung ---------------------------------------------

test_codebook <- paste(
  readLines("testing/testprompts/testprompt_ohne Bsp.txt", encoding = "UTF-8"),
  collapse = "\n"
) #Test-Codebook; Kategorien

test_instructions <-  paste(
  readLines("testing/testprompts/Codebook_Instructions.txt", encoding = "UTF-8"),
  collapse = "\n"
) #Informationen zum Task, Datenset, Angaben zu Regeln usw.
  
user_prompt_generate <- paste(
  c(
    "<context>:", test_instructions,
    "",
    "<codebook>:", test_codebook,
    "output_requirements",
    ":", "Gib die Antwort in JSON mit 'code' und 'reasoning' zurück; kurze Begründung auf max. 50 Zeichen."
  ),
  collapse = "\n"
)


prompt_v01 <- hf_instructor_generate$chat(user_prompt_generate)


cat(prompt_v01)

# Test einfache Prompt-Optimierung ---------------------------------------------

#alte "schlechte" prompt um verbesseurng zu testen
prompt_v01 <- " 
**Prompt für die Inhaltsanalyse der Schweizerischen Masseneinwanderungsinitiative 2014**

**Role**: Du bist Experte für Schweizer Politik und politische Kommunikation.

**Task**: Bitte kodiere den folgenden Text nach Frames, die während der Masseneinwanderungsinitiative verwendet wurden.

**Text-Input**: [Hier wird der Text-Input eingegeben, z.B. ein Schweizer Medienartikel aus dem Jahr 2014]

**Codebook**:
Die folgenden 5 Frame-Kategorien sind relevant für die Analyse:
1. Wirtschaftliche Bedrohung: Einwanderung als Belastung für die Wirtschaft, den Arbeitsmarkt oder die Sozialleistungen.
2. Wirtschaftlicher Nutzen: Einwanderung als wirtschaftlich vorteilhaft oder notwendig.
3. Kulturelle Bedrohung: Einwanderung als Bedrohung für die Schweizer Identität oder Werte.
4. Sicherheit: Einwanderung mit Kriminalität, Terrorismus oder Instabilität verbinden.
5. Humanitär: Migranten als Opfer darstellen, die Mitgefühl oder Unterstützung verdienen.

**Format**: Bitte gib die Antwort in JSON-Format zurück, mit den folgenden Feldern:
- `code`: Der dominant codierte Frame (einer der 5 oben genannten Kategorien).
- `reasoning`: Eine kurze Begründung (max. 50 Zeichen) für die Auswahl des dominanten Frames.
"


feedback_text <- "
Sprachliche Konsistenz:
- Problem: Mix aus deutscher Rollenbeschreibung und englischen JSON-Keys kann zu Fehlern im Output führen.
- Änderung: Alle Felder auf Deutsch benennen.
Vage Kategoriedefinitionen:
- Problem: Begriffe wie 'Sicherheit' oder 'Wirtschaft' sind zu breit gefasst.
- Änderung: Schlagworte (Indikatoren) für jede Kategorie im Codebook ergänzen (z.B. bei Wirtschaft: 'Lohndumping', 'Fachkräftemangel').
Änderung: Begründungslimit auf 250 Zeichen erhöhen, um die Qualität der Argumentation beurteilen zu können.
Fehlende Neutral-Kategorie:
- Problem: Rein sachliche Berichte werden aktuell gezwungen, in ein politisches Schema zu passen.
- Änderung: Kategorie '6. Neutral' hinzufügen.
" #Beispielfeedback


user_prompt_optimize <- paste(
  c(
    "<source_materials>", test_instructions, test_codebook,
    "",
    "<current_prompt>", prompt_v01,
    "",
    "<feedback>", feedback_text
  ),
  collapse = "\n"
)

prompt_v02 <- hf_instructor_optimize$chat(user_prompt_optimize)


cat(prompt_v02)
