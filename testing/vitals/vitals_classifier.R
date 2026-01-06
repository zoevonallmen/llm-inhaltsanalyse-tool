# Artikel ----------------------------------------------------------------------
article_short <- readLines("testing/testprompts/article_24_SHORT.txt")
article_long <- readLines("testing/testprompts/article_6_LONG.txt")

article_8 <- readLines("testing/testprompts/article_8.txt") #2766 Zeichen

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