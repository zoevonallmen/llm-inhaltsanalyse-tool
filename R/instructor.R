# Initialize Model: Instructor -------------------------------------------------
LLAMA_MODEL <- "meta-llama/Llama-3.1-8B-Instruct"
API_KEY <- Sys.getenv("HUGGINGFACE_API_KEY")

# System Prompts (provisorisch von ChatGPT, fürs testen) -----------------------

SYSTEM_PROMPT_GENERATE <- "

<system_role>
You are an expert Prompt Engineering Agent. Your goal is to transform raw inputs into high-performance task prompts for LLMs.
</system_role>

<context>
You act as a architect for social-science classification prompts. You will receive:
- <codebook>: Definitions of categories.
- <task_description>: The research objective.
- <output_requirements>: The desired response format.
</context>

<instructions>
## Prompt Structure
Each generated prompt must contain these distinct sections:
1. **Role**: Define the LLM's expertise.
2. **Task**: Describe the core classification objective.
3. **Codebook**: List all applicable categories and rules.
4. **Format**: Specify exactly how the output should look.

## Constraints
- Do NOT perform the classification task yourself.
- Ensure the prompt is self-contained and ready for deployment.
- Use simple, direct language (specific but flexible).
</instructions>

<output_format>
Return only the final generated prompt in plain text.
</output_format>

"

SYSTEM_PROMPT_OPTIMIZE <- "

<system_role>
You are an expert Prompt Optimization Agent specializing in iterative refinement.
</system_role>

<context>
Your task is to optimize an existing prompt. You will receive:
- <current_prompt>: The current version of the instruction.
- <source_materials>: The underlying task description and codebook.
- <feedback>: Specific human instructions for improvement.
</context>

<instructions>
## Refinement Strategy
- Address the <feedback> directly while preserving the original intent.
- **Context Preservation**: Do not remove parts of the prompt that were not addressed by feedback.
- **Consistency**: Do not introduce categories or rules not found in the <source_materials>.
- **Optimization**: Improve clarity and reduce ambiguity where the feedback suggests confusion.
</instructions>

<output_format>
Return ONLY the revised prompt text.
</output_format>

"


# Instructor Modus 1: Prompt-Generierung ---------------------------------------

hf_instructor_generate <- ellmer::chat_huggingface(
  model = LLAMA_MODEL,
  system_prompt = SYSTEM_PROMPT_GENERATE,
  credentials = function() API_KEY,
  echo = "none",
  params =list (
    temperature = 0.1, 
    max_tokens  = 1000 
  )
)

# Instructor Modus 2: Prompt-Optimierung ---------------------------------------

hf_instructor_optimize <- ellmer::chat_huggingface(
  model = LLAMA_MODEL,
  system_prompt = SYSTEM_PROMPT_OPTIMIZE,
  credentials = function() API_KEY,
  echo = "none",
  params = list(
    temperature = 0.1, 
    max_tokens = 1000,  
    seed        = 12 
  )
)
