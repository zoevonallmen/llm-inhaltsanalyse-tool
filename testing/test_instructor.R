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
    "KONTEXT:", test_instructions,
    "",
    "CODEBOOK:", test_codebook,
    "",
    "OUTPUT REQUIREMENTS:", "Gib die Antwort in JSON mit 'code' und 'reasoning' zurück; kurze Begründung auf max. 50 Zeichen."
  ),
  collapse = "\n"
)

prompt_v01 <- hf_instructor_generate$chat(user_prompt_generate)


cat(prompt_v01)

# Test einfache Prompt-Optimierung ---------------------------------------------

feedback_text <- "
- Ersetze vage Begriffe wie 'reflektiere' durch klare Entscheidungsregeln: 
  Prüfe für jede Kategorie, ob Kriterien erfüllt sind, und wähle die Kategorie mit den meisten erfüllten Kriterien.
- Operationalisiere den 'dominanten Frame': 
  Eine Kategorie gilt als dominant, wenn der Text ein klares Beispiel oder eine konkrete Aussage enthält, die die Kategorie unterstützt und der Text keine Hinweise auf eine andere Kategorie enthält, die stärker unterstützt wird. 
- Wenn der Text keiner Kategorie klar zugeordnet werden kann, wähle 'Keine Anwendung' als code.
- Reasoning-Länge: maximal 2 kurze Sätze; wiederhole keine Definitionen aus dem Codebook.
" #Beispielfeedback

user_prompt_optimize <- paste(
  c(
    "ORIGINAL KONTEXT:", test_instructions,
    "",
    "ORIGINAL CODEBOOK:", test_codebook,
    "",
    "CURRENT TASK PROMPT:", prompt_v01,
    "",
    "FEEDBACK:", feedback_text
  ),
  collapse = "\n"
)

prompt_v02 <- hf_instructor_optimize$chat(user_prompt_optimize)


cat(prompt_v02)