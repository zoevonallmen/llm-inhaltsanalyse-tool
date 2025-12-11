#Initialize model -----------------------------------------------------------------------

LLAMA_MODEL <- "meta-llama/Llama-3.1-8B-Instruct"
API_KEY <- Sys.getenv("HUGGINGFACE_API_KEY")

hf_model <- ellmer::chat_huggingface(
  system_prompt = "Du bist der Classifier. Deine Aufgabe ist die strikte Anwendung des Codierschemas. Antworte IMMER im JSON-Format mit den Feldern 'code' und 'reasoning'.",  #system-prompt noch überarbeiten/begründe; und DE or EN?
  params(
    temperature = 0.0, #?
    max_tokens = 300 #?
  ),
  model = LLAMA_MODEL,
)
