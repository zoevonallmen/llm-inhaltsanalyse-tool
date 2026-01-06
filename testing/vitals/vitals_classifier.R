# Artikel ----------------------------------------------------------------------
article_short <- readLines("testing/testprompts/article_24_SHORT.txt")
article_long <- readLines("testing/testprompts/article_6_LONG.txt")

# article_8 <- readLines("testing/testprompts/article_8.txt") #2766 Zeichen

# Prompts ---------------------------------------------------------------------
prompt_short <- "Codieren Sie den Text nach den Kriterien 'Wirtschaft', 'Sicherheit', 'Kultur' oder 'Humanitär' und begründen Sie Ihre Wahl."

prompt_long <- paste(
  readLines("testing/testprompts/testprompt_ohne Bsp.txt", encoding = "UTF-8"),
  collapse = "\n"
)

prompt_long_with_examples <- paste(
  readLines("testing/testprompts/testprompt_mit Bsp.txt", encoding = "UTF-8"),
collapse = "\n"
) #--> evtl. auch noch testen? 

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

artikel_für_loop <- list(
  article_long,
  article_long,
  article_long,
  article_long,
  article_long,
  article_short,
  article_short,
  article_short,
  article_short,
  article_short
)


loop_results <- lapply(seq_along(artikel_für_loop), function(i) {
  
  hf_model <- ellmer::chat_huggingface(
    system_prompt = "Du bist der Classifier. Deine Aufgabe ist die strikte Anwendung des Codierschemas. Antworte IMMER im JSON-Format mit den Feldern 'code' und 'reasoning'.",  #system-prompt noch überarbeiten/begründen; und DE or EN?
    model = LLAMA_MODEL,
    credentials = function() API_KEY,
    params = list(
      temperature = 0.0,#?
      max_new_tokens = 300 #?
    ),
    echo = "none"
  ) #aus Classifier.R kopiert; hf_model für jeden Artikel neu initialisieren...
  
  res <- classifier(
    article_text = artikel_für_loop[[i]],
    prompt = prompt_long,
    chat_object = hf_model
  )
  
  
  list(
    run        = i,
    success    = res$success,
    code       = res$code,
    reasoning  = res$reasoning,
    raw        = res$raw,
    error      = res$error
  )
})




loop_df <- bind_rows(loop_results)

print(loop_df)
