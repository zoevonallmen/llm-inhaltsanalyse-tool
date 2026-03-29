# Tool für LLM-gestütze Inhaltsanalyse

Dieses Projekt implementiert einen **Human-in-the-Loop Agentic Workflow** zur (qualitativen) Codierung von Textdaten mittels LLMs. Das Tool wird als **Shiny-App** in RStudio entwickelt.

------------------------------------------------------------------------

## Agentenbasierte Architektur

Der Analyseprozess wird in funktional spezialisierte Rollen aufgeteilt:

| Agent | Aufgabe |
|----|----|
| Instructor | Generierung und Optimierung von Prompts |
| Classifier | Klassifikation der Texte |
| Menschliche Forschende | Definition der Analyseaufgabe, Evaluation und Validierung |

------------------------------------------------------------------------

### Iterative Prompt-Entwicklung

Prompts werden nicht einmalig erstellt, sondern in einem iterativen Prozess entwickelt:

1.  Generierung einer initialen Prompt
2.  Testlauf an einem Subsample, Abgleich mit manuellen Codierungen
3.  Analyse von Fehlklassifikationen
4.  Anpassung der Prompt
5.  Erneuter Testlauf

Dieser Prozess entspricht der iterativen Logik klassischer Codierprozesse in der qualitativen Inhaltsanalyse.

------------------------------------------------------------------------

### Chain-of-Thought Reasoning

Der Classifier gibt zu jeder Klassifikation zusätzlich eine Begründung aus. Diese Begründungen können genutzt werden, um Fehlinterpretationen des Modells zu identifizieren und Prompts gezielt zu verbessern.

------------------------------------------------------------------------

### Prompt-Versionierung

Alle Prompt-Versionen werden automatisch gespeichert. Frühere Versionen können jederzeit wiederverwendet oder erneut getestet werden.

------------------------------------------------------------------------

### Audit Trail

Der gesamte Analyseprozess wird automatisch dokumentiert. Der Export umfasst unter anderem:

-   Die verwendete Prompt\
-   Alle generierten und optimierten Prompt-Versionen\
-   Feedback und Begründungen für Änderungen\
-   Ergebnisse der Subsample-Evaluation\
-   Ergebnisse der Batch-Klassifikation\
-   Modellkonfiguration und Modellparameter

------------------------------------------------------------------------

# Systemarchitektur

Die Anwendung basiert auf einer modularen Struktur aus drei Komponenten:

| Datei          | Funktion                                            |
|----------------|-----------------------------------------------------|
| `app.R`        | Shiny-Oberfläche und Steuerung des Analyseworkflows |
| `instructor.R` | Generierung und Optimierung der Prompts             |
| `classifier.R` | Klassifikation der Texte und JSON-Parsing           |

Die Kommunikation mit Sprachmodellen erfolgt über die **HuggingFace Inference API** mithilfe des R-Pakets `ellmer`.

Die Anwendung wurde in **R** entwickelt und nutzt folgende Pakete:

-   `shiny`
-   `shinythemes`
-   `ellmer`
-   `jsonlite`
-   `stringr`
-   `here`

Aktuell verwendetes Sprachmodell: meta-llama/Llama-3.3-70B-Instruct

------------------------------------------------------------------------

## Schritte des Workflows

Die Anwendung umfasst fünf Schritte:

### 1. Inputs

Zu Beginn werden folgende Inputs definiert:

-   Codebuch (Upload als .txt oder .md)

-   Aufgabenbeschrieb (freies Textfeld)

-   Output-Anforderungen (JSON Format mit Felder "code" und "reasoning")

Diese Informationen bilden die Grundlage für die Prompt-Generierung.

Die Prompt-Generierung kann mit dem Button "Prompt generieren" gestartet werden.

------------------------------------------------------------------------

### 2. Prompt-Entwicklung

Der Instructor-Agent generiert auf Basis der Inputs eine strukturierte Klassifikationsprompt.

Anschliessend können Forschende:

-   Feedback geben (freies Textfeld, wird an das Modell übermittelt)

-   Die Begründung für die Änderung dokumentieren (freiesTextfeld, wird nicht ans Modell übergeben)

-   die Prompt iterativ optimieren (via Button "Prompt optimieren")

-   verschiedene Prompt-Versionen testen

------------------------------------------------------------------------

### 3. Subsample-Test

Ein manuell codiertes Subsample wird hochgeladen.

Der Classifier analysiert diese Texte und liefert:

-   Klassifikation

-   Begründung (Reasoning)

Die Ergebnisse können mit den manuellen Codierungen verglichen werden.

------------------------------------------------------------------------

### 4. Batch-Klassifikation

Nach erfolgreicher Kalibrierung der Prompt kann der vollständige Datensatz klassifiziert werden.

Jedes Dokument wird unabhängig verarbeitet.

------------------------------------------------------------------------

### 5 Export / Audit Trail

Der gesamte Analyseprozess kann als Archiv exportiert werden.

Der Export enthält unter anderem:

-   Modellname, Modellparameter, Systemprompts

-   Alle Prompt-Versionen

-   Subsample-Ergebnisse

-   Klassifikationsergebnisse

-   Prozesslogs
