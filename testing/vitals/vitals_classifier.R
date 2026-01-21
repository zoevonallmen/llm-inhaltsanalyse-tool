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
  prompt = prompt_v02,
  chat_object = hf_model
)

response$success
response$code
response$reasoning
response$raw


# Loop ----------------------------------------------------------------------------
source("R/classifier.R")

prompt_v02 <- "
**Prompt für die Inhaltsanalyse der Schweizerischen Masseneinwanderungsinitiative 2014**

**Role**: Du bist Experte für Schweizer Politik und politische Kommunikation.

**Task**: Bitte kodiere den folgenden Text nach Frames, die während der Masseneinwanderungsinitiative verwendet wurden.

**Text-Input**: [Hier wird der Text-Input eingegeben, z.B. ein Schweizer Medienartikel aus dem Jahr 2014]

**Codebook**:
Die folgenden 6 Frame-Kategorien sind relevant für die Analyse:
1. Wirtschaftliche Bedrohung: Einwanderung als Belastung für die Wirtschaft, den Arbeitsmarkt oder die Sozialleistungen. Indikatoren: Lohndumping, Fachkräftemangel.
2. Wirtschaftlicher Nutzen: Einwanderung als wirtschaftlich vorteilhaft oder notwendig. Indikatoren: Wirtschaftswachstum, Arbeitsplatzschaffung.
3. Kulturelle Bedrohung: Einwanderung als Bedrohung für die Schweizer Identität oder Werte. Indikatoren: Kulturelle Assimilation, Werteverfall.
4. Sicherheit: Einwanderung mit Kriminalität, Terrorismus oder Instabilität verbinden. Indikatoren: Kriminalitätszahlen, Terrorismusvorwürfe.
5. Humanitär: Migranten als Opfer darstellen, die Mitgefühl oder Unterstützung verdienen. Indikatoren: Menschenrechtsverletzungen, Flüchtlingsnot.
6. Neutral: Sachliche Berichte, die keine politische Meinung vermitteln. Indikatoren: Faktenberichterstattung, Objektivität.

**Format**: Bitte gib die Antwort in JSON-Format zurück, mit den folgenden Feldern:
- `dominanter-Frame`: Der dominant codierte Frame (einer der 6 oben genannten Kategorien).
- `begründung`: Eine kurze Begründung (max. 250 Zeichen) für die Auswahl des dominanten Frames.
"

short_articles <- rep(list(article_short), 25)

long_articles <- rep(list(article_long), 25)

artikel_für_loop <- c(short_articles, long_articles)


loop_results <- lapply(seq_along(artikel_für_loop), function(i) {
  
  hf_model <- ellmer::chat_huggingface(
    system_prompt = SYSTEM_PROMPT_CLASSIFIER,
    model = LLAMA_MODEL,
    credentials = function() API_KEY,
    params = list(
      temperature = 0.0,
      max_tokens  = 300,
      seed        = 24
    ),
    echo = "none"
  )
  
  
  start_time <- Sys.time()
  
  res <- classifier(
    article_text = artikel_für_loop[[i]],
    prompt = prompt_v02,
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


