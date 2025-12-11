# Tool für LLM-gestütze Inhaltsanalyse

Dieses Projekt implementiert einen **Human-in-the-Loop Agentic Workflow** zur (qualitativen) Codierung von Textdaten mittels LLMs. Das Tool wird als **Shiny-App** in RStudio entwickelt und nutzt das `ellmer`-Paket.

## 1. Konzept & Methodologische Grundidee

Der Workflow gliedert die Aufgaben in spezialisierte Agenten, um die mangelnde Systematik im Prompt-Engineering und das Intransparenzproblem von LLMs zu adressieren (Farjam et al. (2025))

-   **Human Intermediary:** Definition der Aufgabe & die Validierung der Prompt-Resultate.
-   **Instructor (LLM):** Meta-Prompting; Prompt-Generierung & Prompt-Optimierung.
-   **Classifier (LLM):** Codierung inkl. CoT-Begründung.

## 2. Workflow-Schema

| Schritt | Rolle(n) | Fokus und Logik |
|:-----------------------|:-----------------------|:-----------------------|
| **1. Definition** | Human Intermediary | Upload Datensatz, Eingabe Codebuch/Kategoriensystem und Beschreibung der Codieraufgabe. |
| **2. Prompt-Generierung** | Instructor | LLM erstellt aus den menschlichen Anweisungen die Prompt V1 (Meta-Prompting). Das Ergebnis wird versioniert gespeichert. |
| **3. Subsample Codierung** | Classifier | Durchführung der Codierung eines Test-Subsamples. Liefert JSON-Output mit Codierung und CoT-Begründung. |
| **4. Iterative Optimierung** | Human Intermediary & Instructor | Human Intermediary liefert Feedback (Problem/Korrektur). Instructor optimiert Prompt. |
| **5. Finale Codierung** | Classifier | Batch-Verarbeitung des gesamten Datensatzes mit der finalen Prompt. Ergebnisspeicherung (inkl. aller CoT-Begründungen). |

## 3. Technische Spezifikationen

-   **Modell:** meta-llama/Llama-3.1-8B-Instruct
-   **LLM-Zugang:** Hugging Face Inference API...
