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

print(raw_response_list$success)
print(raw_response_list$code)
print(raw_response_list$reasoning)

# Output: 
# > print(raw_response_list$success)
# [1] TRUE
# > print(raw_response_list$code)
# [1] "Politik"
# > print(raw_response_list$reasoning)
# [1] "Der Text handelt von einem Gesetzesentwurf der Bundesregierung, der sich mit der Förderung der Kreislaufwirtschaft beschäftigt. Dies ist ein Politikthema, da es sich um eine Maßnahme der Regierung handelt, die darauf abzielt, die Recyclingquoten zu erhöhen und die Industrie zu verpflichten, mehr recycelte Materialien zu verwenden."

# (Funktioniert, Aber vorher Code = Soziales, jetzt Politik)