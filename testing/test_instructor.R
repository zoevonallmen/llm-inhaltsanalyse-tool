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
  
user_prompt <- paste(
  c(
    "KONTEXT:", test_instructions,
    "",
    "CODEBOOK:", test_codebook,
    "",
    "OUTPUT REQUIREMENTS:", "Gib die Antwort in JSON mit 'code' und 'reasoning' zurück; kurze Begründung auf max. 50 Zeichen."
  ),
  collapse = "\n"
)

prompt_v01 <- hf_instructor_generate$chat(user_prompt)


cat(prompt_v01)

# Test einfache Prompt-Optimierung ---------------------------------------------