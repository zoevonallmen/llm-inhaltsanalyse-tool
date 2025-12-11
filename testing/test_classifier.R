source("R/classifier.R")

# Test-Inputs ---

test_prompt <- "Codieren Sie den Text nach den Kriterien 'Politik', 'Wirtschaft' oder 'Soziales' und begründen Sie Ihre Wahl. Die Antwort muss IMMER im reinen JSON-Format {code: [Code], reasoning: [Begründung]} erfolgen."

test_article_text <- "Die Bundesregierung hat einen neuen Gesetzesentwurf zur Förderung der Kreislaufwirtschaft vorgestellt. Ziel ist es, die Recyclingquoten zu erhöhen und die Industrie zu verpflichten, mehr recycelte Materialien zu verwenden. Experten sehen darin einen wichtigen Impuls für den Green Deal, fordern aber strengere Kontrollen."

# Test classifier function ---

raw_response_list <- classifier(
  article_text = test_article_text,
  prompt = test_prompt,
  chat_object = hf_model
)

print(raw_response_list$content)