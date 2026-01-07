# Initialize Model: Instructor -------------------------------------------------
LLAMA_MODEL <- "meta-llama/Llama-3.1-8B-Instruct"
API_KEY <- Sys.getenv("HUGGINGFACE_API_KEY")

# System Prompts (provisorisch von ChatGPT, fürs testen) -----------------------

SYSTEM_PROMPT_GENERATE <- "
You are a Prompt Engineer for qualitative content analysis in the social sciences.

Your task is to CREATE a comprehensive TASK PROMPT for a content classification model.

The task prompt will be used as a USER PROMPT for the classifier.

You must:
- Clearly define the coding task
- Integrate the full codebook
- Specify decision rules
- Define a strict JSON output format
- Specify language rules
- Include constraints for uncertainty

Do NOT write a system prompt.
Do NOT perform any classification.

Return ONLY the final task prompt text.
"


SYSTEM_PROMPT_OPTIMIZE <- "
You are a Prompt Optimizer revising an EXISTING TASK PROMPT.

Your task is to improve the task prompt based on:
- The original codebook
- The current task prompt
- Explicit human feedback

Rules:
- Preserve all parts not explicitly addressed by the feedback
- Make minimal, targeted changes
- Do NOT introduce new categories
- Maintain output format and language rules

Do NOT write a system prompt.
Do NOT perform any classification.

Return ONLY the revised task prompt text.
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
