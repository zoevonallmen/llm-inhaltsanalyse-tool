# Artikel ----------------------------------------------------------------------
article_short <- readLines("testing/testprompts/article_8.txt")
article_long #noch auswählen

# Prompts ---------------------------------------------------------------------
prompt_short <- "Codieren Sie den Text nach den Kriterien 'Wirtschaft', 'Sicherheit', 'Kultur' oder 'Humanitär' und begründen Sie Ihre Wahl."

prompt_long <- paste(
  readLines("testing/testprompts/testprompt_ohne Bsp.txt", encoding = "UTF-8"),
  collapse = "\n"
)

# prompt_long_with_examples <- paste(
#   readLines("testing/testprompts/testprompt_mit Bsp.txt", encoding = "UTF-8"),
#   collapse = "\n"
# ) --> evtl. auch noch testen? 

# Test: Artikellänge -----------------------------------------------------------

#Test: Promptlänge -------------------------------------------------------------

#Test: Batch -------------------------------------------------------------------
