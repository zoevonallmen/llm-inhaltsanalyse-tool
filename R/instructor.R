# Initialize Model: Instructor -------------------------------------------------
LLAMA_MODEL <- "meta-llama/Llama-3.1-8B-Instruct"
API_KEY <- Sys.getenv("HUGGINGFACE_API_KEY")

# System Prompts (provisorisch von ChatGPT, fürs testen) -----------------------

SYSTEM_PROMPT_GENERATE <- "

<system_role>
You are an expert Prompt Engineering Agent specializing in social-science classification tasks. Your goal is to transform raw inputs into a complete, deployment-ready classification prompt.
</system_role>

<context>
You will receive the following input materials:
- <codebook>: A Codebook containing categories, definitions and coding rules, anchor examples and delimination rules.
- <task_description>: The research objective.
- <output_requirements>: The desired response format für the classification agent.
</context>

<instructions>
## Prompt Structure
You must generate the rompt exactly after the following structure:
1. **Rolle**: Assign the classification agent's role in second person, tailored to the <task_description>.
2. **Task**: Describe the core classification objective based on the <task_description>.
3. **Codebook**: Reproduce the <codebook> in this order:
   1. Coding rules
   2. Frame definitions
4. **Format**: Use the <output_requirements> to define a strict response format. Specify:
   - The exact structure with all required fields
   - An example output demonstrating the expected reasoning structure

## Example (abbreviated)
Role section: 'You are an expert in [domain] specializing in [task].'

Reasoning example in output format:
{
  'code': 2,
  'reasoning': 'The text shows [observation about content]. 
  This matches the definition of [Category] because [link to definition].'
}

## Constraints
- Do NOT perform the classification task yourself.
- Ensure the prompt is self-contained and ready for deployment.
- Use simple, direct language (specific but flexible).
- Write the prompt in the same language as the input materials.
- Reproduce the codebook fully, do not compress or rewrite it.
</instructions>

<output_format>
Return only the final generated prompt in plain text. Do not add any meta-commentary or explanation.
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
- **Context Preservation**: Apply the minimum necessary changes to address the feedback. Only modify what the feedback explicitly targets. Do not delete or modify anything that's not adressed by the feedback.
- **Consistency**: Do not introduce categories or rules not found in the <source_materials>.
- **Optimization**: Improve clarity and reduce ambiguity where the feedback suggests confusion.
</instructions>

<output_format>
Return only the final revised prompt in plain text. 
Do NOT add any introductory headers that were not part or <current prompt>, such as '**Revised Prompt**'.
</output_format>

"


# Instructor Modus 1: Prompt-Generierung ---------------------------------------

hf_instructor_generate <- ellmer::chat_huggingface(
  model = LLAMA_MODEL,
  system_prompt = SYSTEM_PROMPT_GENERATE,
  credentials = function() API_KEY,
  echo = "none",
  params =list (
    temperature = 0.0, 
    max_tokens  = 3000
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
    max_tokens = 3000,  
    seed        = 12 
  )
)


# Für App Export: --------------------------------------------------------------

INSTRUCTOR_GENERATE_MODEL <- LLAMA_MODEL
INSTRUCTOR_GENERATE_PARAMS <- list(
  temperature = 0.1,
  max_tokens  = 1000
)

INSTRUCTOR_OPTIMIZE_MODEL <- LLAMA_MODEL
INSTRUCTOR_OPTIMIZE_PARAMS <- list(
  temperature = 0.1,
  max_tokens  = 1000,
  seed        = 12
)
