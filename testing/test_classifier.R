source("R/classifier.R")

# Test-Inputs ------------------------------------------------------------------

# test_prompt <- "Codieren Sie den Text nach den Kriterien 'Politik', 'Wirtschaft' oder 'Soziales' und begründen Sie Ihre Wahl. Die Antwort muss IMMER im reinen JSON-Format {code: [Code], reasoning: [Begründung]} erfolgen."
# 
# test_article_text <- "Die Bundesregierung hat einen neuen Gesetzesentwurf zur Förderung der Kreislaufwirtschaft vorgestellt. Ziel ist es, die Recyclingquoten zu erhöhen und die Industrie zu verpflichten, mehr recycelte Materialien zu verwenden. Experten sehen darin einen wichtigen Impuls für den Green Deal, fordern aber strengere Kontrollen."


 read_text_file <- function(path) {
  paste(readLines(path, encoding = "UTF-8"), collapse = "\n")
}


test_article_text <- read_text_file("testing/testprompts/article_8.txt")

test_prompt <- paste(
  readLines("testing/testprompts/testprompt_ohne Bsp.txt", encoding = "UTF-8")#,
  #collapse = "\n"
)

# Test classifier function -----------------------------------------------------

response <- classifier(
  article_text = test_article_text,
  prompt = test_prompt,
  chat_object = hf_model
)

print(response$success)
print(response$code)
print(response$reasoning)
print(response$raw)
print(response$json)
print(response$error)

# > print(response$success)
# [1] TRUE
# > print(response$code)
# [1] "Wirtschaftlicher Nutzen"
# > print(response$reasoning)
# [1] "Der Artikel stellt Einwanderung als wirtschaftlich vorteilhaft dar, indem er betont, dass die Schweiz die Zuwanderung wieder eigenständig steuern können muss, um das Wachstum der Schweizer Wirtschaft zu fördern. Peter Föhn argumentiert, dass die Schweiz die Personenfreizügigkeit mit der EU nachverhandeln muss, um die wirtschaftlichen Vorteile der Einwanderung zu nutzen. Dies deutet darauf hin, dass der Artikel den Frame 'Wirtschaftlicher Nutzen' verwendet, um Einwanderung zu präsentieren."
# > print(response$raw)
# ```json
# {
#   "code": "Wirtschaftlicher Nutzen",
#   "reasoning": "Der Artikel stellt Einwanderung als wirtschaftlich 
# vorteilhaft dar, indem er betont, dass die Schweiz die Zuwanderung wieder 
# eigenständig steuern können muss, um das Wachstum der Schweizer Wirtschaft zu
# fördern. Peter Föhn argumentiert, dass die Schweiz die Personenfreizügigkeit 
# mit der EU nachverhandeln muss, um die wirtschaftlichen Vorteile der 
# Einwanderung zu nutzen. Dies deutet darauf hin, dass der Artikel den Frame 
# 'Wirtschaftlicher Nutzen' verwendet, um Einwanderung zu präsentieren."
# }
# ```
# > print(response$json)
# [1] "{\n  \"code\": \"Wirtschaftlicher Nutzen\",\n  \"reasoning\": \"Der Artikel stellt Einwanderung als wirtschaftlich vorteilhaft dar, indem er betont, dass die Schweiz die Zuwanderung wieder eigenständig steuern können muss, um das Wachstum der Schweizer Wirtschaft zu fördern. Peter Föhn argumentiert, dass die Schweiz die Personenfreizügigkeit mit der EU nachverhandeln muss, um die wirtschaftlichen Vorteile der Einwanderung zu nutzen. Dies deutet darauf hin, dass der Artikel den Frame 'Wirtschaftlicher Nutzen' verwendet, um Einwanderung zu präsentieren.\"\n}"
# > print(response$error)
# NULL