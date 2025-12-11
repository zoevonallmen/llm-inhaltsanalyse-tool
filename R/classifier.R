# Load Libraries ---------------------------------------------------------------
library(ellmer)
library(stringr)
library(jsonlite)

# Initialize Model -------------------------------------------------------------
LLAMA_MODEL <- "meta-llama/Llama-3.1-8B-Instruct"
API_KEY <- Sys.getenv("HUGGINGFACE_API_KEY")

hf_model <- ellmer::chat_huggingface(
  system_prompt = "Du bist der Classifier. Deine Aufgabe ist die strikte Anwendung des Codierschemas. Antworte IMMER im JSON-Format mit den Feldern 'code' und 'reasoning'.",  #system-prompt noch überarbeiten/begründen; und DE or EN?
  model = LLAMA_MODEL,
  credentials = function() API_KEY,
  params = list(
    temperature = 0.0,#?
    max_new_tokens = 300 #?
  ),
  echo = "none"
)

# Classifier Function ----------------------------------------------------------

classifier <- function(article_text, prompt, chat_object = hf_model){
  
  user_prompt <- paste0(
    prompt, 
    "\n\n--- Dokument zur Codierung ---\n", 
    article_text
  )

  raw_response <- chat_object$chat(
    user_prompt,
  )
  
  parsed <- tryCatch(
    {
      jsonlite::fromJSON(raw_response)
    },
    error = function(e) {
      NULL
    }
  )
  
  if (is.null(parsed)) {
    return(list(
      success   = FALSE,
      code      = NA_character_,
      reasoning = NA_character_
    ))
  }
  
  code      <- parsed$code
  reasoning <- parsed$reasoning
  
  return(list(
    success   = TRUE,
    code      = as.character(code),#für aktuelles bsp ja, sonst evtl numerischer wert/zahl; muss ich definieren?
    reasoning = as.character(reasoning)
  ))
  
}
