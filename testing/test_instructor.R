source("R/instructor.R")

# Test einfache Promptgenerierung ---------------------------------------------

test_codebook <- paste(
  readLines("testing/testprompts/testprompt_mit Bsp.txt", encoding = "UTF-8"),
  collapse = "\n"
) #Test-Codebook; Kategorien, Beispiele

test_instructions <-  paste(
  readLines("testing/testprompts/Codebook_Instructions.txt", encoding = "UTF-8"),
  collapse = "\n",
) #Informationen zum Task, Datenset, Angaben zu Regeln usw.
  
user_prompt <- paste(
  c(
    "CODEBOOK:", test_codebook,
    "",
    "KONTEXT:", test_instructions,
    "",
    "OUTPUT REQUIREMENTS:", "Gib die Antwort in JSON mit 'code' und 'reasoning' zurück; kurze Begründung auf max. 50 Zeichen."
  ),
  collapse = "\n"
)