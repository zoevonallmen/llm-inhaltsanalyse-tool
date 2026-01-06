# Load Libraries ---------------------------------------------------------------
library(ellmer)
library(jsonlite)

# Initialize Model -------------------------------------------------------------
LLAMA_MODEL <- "meta-llama/Llama-3.1-8B-Instruct"
API_KEY <- Sys.getenv("HUGGINGFACE_API_KEY")

hf_model <- ellmer::chat_huggingface(
  system_prompt = "Du bist der Classifier. Deine Aufgabe ist die strikte Anwendung des Codierschemas. Antworte IMMER im JSON-Format mit den Feldern 'code' und 'reasoning'.",  #system-prompt noch überarbeiten/begründen; und DE or EN?
  model = LLAMA_MODEL,
  credentials = function() API_KEY,
  params = list(
    temperature = 0.0,
    max_new_tokens = 300#?
  ),
  echo = "none"
)


#Helper Function (extract_json)-------------------------------------------------

library(stringr)

extract_json <- function(x) {
  if (is.null(x) || length(x) == 0) return(NULL)
  
  x <- as.character(x)[1]
  
  m <- str_match(x, "```(?:json)?\\s*([\\s\\S]*?)\\s*```")
  if (!is.na(m[1,2])) {
    return(str_trim(m[1,2]))
  }
  
  start <- str_locate(x, fixed("{"))[1]
  ends  <- str_locate_all(x, fixed("}"))[[1]]
  
  if (is.na(start) || nrow(ends) == 0) return(NULL)
  
  end <- ends[nrow(ends), "end"]
  
  str_trim(substr(x, start, end))
}

# Classifier Function ----------------------------------------------------------

classifier <- function(article_text, prompt, chat_object = hf_model,
                       max_attempts = 3, sleep_sec = 5){ #weiss nicht wieviel von beidem sinvoll ist, muss geprüft werden!!!
  
 attempt <- 1
 while(attempt <= max_attempts) {
   
  user_prompt <- paste0(
    prompt, 
    "\n\n--- Dokument zur Codierung ---\n", 
    article_text
  )

  raw_response <- tryCatch({
    chat_object$chat(user_prompt, echo = "none")
  }, error = function(e) e)
  
  if(!inherits(raw_response, "error")) {
   
    parsed <- tryCatch(jsonlite::fromJSON(raw_response), error = function(e) NULL)
    json_used <- raw_response
  
  if (is.null(parsed)) {
    json_candidate <- extract_json(raw_response)
    
    if (!is.null(json_candidate)) {
      parsed <- tryCatch(
        jsonlite::fromJSON(json_candidate),
        error = function(e) NULL
      )
      json_used <- json_candidate
    }
  }
  
  
  if (is.null(parsed)) {
    return(list(
      success   = FALSE,
      code      = NA,
      reasoning = NA,
      raw = raw_response,
      json = NA,
      error = "JSON parsing failed"
    ))
  } else {
    return(list(
    success   = TRUE,
    code      = parsed$code,
    reasoning = parsed$reasoning,
    raw       = raw_response,
    json      = json_used, 
    error     = NULL
  ))
  }

  } else {
    
    message(paste0("Fehler", attempt, "/", max_attempts, ". Retry in ", sleep_sec, " Sekunden"))
    Sys.sleep(sleep_sec)
    attempt <- attempt + 1
  }
 }
 
 list (
   success   = FALSE,
   code      = NA,
   reasoning = NA,
   raw       = NA,
   json      = NA,
   error     = "Max attempts reached without success"
 )
}


  