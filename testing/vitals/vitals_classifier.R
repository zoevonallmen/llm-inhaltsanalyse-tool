# Artikel ----------------------------------------------------------------------
article_short <- readLines("testing/testprompts/article_24_SHORT.txt")
article_long <- readLines("testing/testprompts/article_6_LONG.txt")

# article_8 <- readLines("testing/testprompts/article_8.txt") #2766 Zeichen

# Prompts ---------------------------------------------------------------------

#prompt_short <- "Codieren Sie den Text nach den Kriterien 'Wirtschaft', 'Sicherheit', 'Kultur' oder 'Humanitär' und begründen Sie Ihre Wahl."

prompt_long <- paste(
  readLines("testing/testprompts/testprompt_ohne Bsp.txt", encoding = "UTF-8"),
  collapse = "\n"
)

# prompt_long_with_examples <- paste(
#   readLines("testing/testprompts/testprompt_mit Bsp.txt", encoding = "UTF-8"),
# collapse = "\n"
# ) 

# Test: Artikel- und Promptlänge ----------------------------------------------
source("R/classifier.R")

response <- classifier(
  article_text = article_long,
  prompt = prompt_long_with_examples,
  chat_object = hf_model
)

response$success
response$code
response$reasoning
response$raw


# Loop ----------------------------------------------------------------------------

short_articles <- rep(list(article_short), 25)

long_articles <- rep(list(article_long), 25)

artikel_für_loop <- c(short_articles, long_articles)


loop_results <- lapply(seq_along(artikel_für_loop), function(i) {

  hf_model <- ellmer::chat_huggingface(
    system_prompt = "Du bist der Classifier. Deine Aufgabe ist die strikte Anwendung des Codierschemas. Antworte IMMER im JSON-Format mit den Feldern 'code' und 'reasoning'.",  #system-prompt noch überarbeiten/begründen; und DE or EN?
    model = LLAMA_MODEL,
    credentials = function() API_KEY,
    params = list(
      temperature = 0.0,
      max_new_tokens = 300 #generiert immer eine Warnung: Ignoring unsupported parameters: "max_new_tokens" aber funktioniert...
    ),
    echo = "none"
  )
  
  start_time <- Sys.time()
  
  res <- classifier(
    article_text = artikel_für_loop[[i]],
    prompt = prompt_long,
    chat_object = hf_model
  )
  
  end_time <- Sys.time()
  
  list(
    run        = i,
    success    = res$success,
    code       = res$code,
    reasoning  = res$reasoning,
    raw        = res$raw,
    latency_s  = as.numeric(difftime(end_time, start_time, units = "secs")),
    error      = res$error
  )
})

