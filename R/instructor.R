# Initialize Model: Instructor -------------------------------------------------
LLAMA_MODEL <- "meta-llama/Llama-3.1-8B-Instruct"
API_KEY <- Sys.getenv("HUGGINGFACE_API_KEY")

# System Prompts (provisorisch von ChatGPT, fürs testen) -----------------------

SYSTEM_PROMPT_GENERATE <- "
You are a prompt engineering agent.

Your task is to generate task prompts for an instruction-following
large language model.

You will receive codebooks, task descriptions, and output requirements
via the user prompt.

Generate task prompts with a consistent, clearly organized structure.
Each prompt should define the role of the model, describe the task,
specify the applicable codebook or categories, and state the required
output format.

Transform the provided inputs into a clear, self-contained task prompt
in plain text.

Do not perform the task yourself.
"
### vergessen: evtl. noch Anweisung, für jeden Task eine eigene Prompt zu generieren? // Subtasks

SYSTEM_PROMPT_OPTIMIZE <- "
You are a prompt optimization agent.

Your task is to improve existing task prompts for an instruction-following
large language model based on human feedback.

You will receive the original task prompt, the original task description and codebook,
and human feedback via the user prompt.

Revise the task prompt to address the feedback while preserving the original
task intent and overall structure.

Do not perform the task yourself.
Preserve all parts not explicitly addressed by the feedback. 
Do not introduce new categories or rules.


Output only the revised task prompt in plain text.
"


# Instructor Modus 1: Prompt-Generierung ---------------------------------------

hf_instructor_generate <- ellmer::chat_huggingface(
  model = LLAMA_MODEL,
  system_prompt = SYSTEM_PROMPT_GENERATE,
  credentials = function() API_KEY,
  echo = "none",
  params = list(
    temperature = 0.0, #?
    max_tokens = 1000  #? 
  )
)

# Instructor Modus 2: Prompt-Optimierung ---------------------------------------

hf_instructor_optimize <- ellmer::chat_huggingface(
  model = LLAMA_MODEL,
  system_prompt = SYSTEM_PROMPT_OPTIMIZE,
  credentials = function() API_KEY,
  echo = "none",
  params = list(
    temperature = 0.0, #?
    max_tokens = 1000  #? 
  )
)
