# Initialize Model: Instructor -------------------------------------------------
LLAMA_MODEL <- "meta-llama/Llama-3.3-70B-Instruct"
API_KEY <- Sys.getenv("HUGGINGFACE_API_KEY")

# System Prompts (provisorisch von ChatGPT, fürs testen) -----------------------

SYSTEM_PROMPT_GENERATE <- "

<system_role>
You are an expert Prompt Engineering Agent specializing in social-science classification tasks. Your goal is to transform raw inputs into a complete, deployment-ready classification prompt.
</system_role>

<task>
Your task is to generate a prompt that instructs a classification agent to apply the codebook reliably to new text inputs.
</task>

<context>
You will receive the following input materials:
- <codebook>: A Codebook containing categories, definitions and coding rules, anchor examples and delimination rules.
- <task_description>: The research objective.
- <output_requirements>: The desired response format für the classification agent.
</context>

<instructions>
## Prompt Structure
Generate the prompt using the following structure. The sections must appear clearly separated using headers such as '# Role', '# Task', '# Codebook', and '# Output Format'.
1. **Rolle**: Assign the classification agent a clear role in second person, tailored to the <task_description>.
   Example: 'You are an expert in [domain] specializing in [task].'
2. **Task**: Describe the core classification objective based on the <task_description>.
3. **Codebook**: Integrate the into the prompt while preserving all definitions, rules, and examples. Do not change the meaning of any category, rule, or definition.
4. **Format**: Use the <output_requirements> to define a strict response format. Specify:
   - The exact structure with all required fields
   - That the reasoning must explain the classification step-by-step by linking textual evidence to the relevant codebook definition.
   
   Include a short example output demonstrating the reasoning srtcuture. 
   Example:

   Reasoning example in output format:
   {
     'code': 2,
     'reasoning': 'The text mentions [observation about content]. 
     This matches the definition of [Category] because [link to definition].'
   }

## Constraints
- Do NOT perform the classification task yourself.
- Ensure the prompt is self-contained and ready for deployment.
- Use simple, direct language (specific but flexible).
- The generated prompt must be written entirely in the same language as the <task_description> input. Do not mix languages.
</instructions>

<output_format>
Return only the final generated prompt in plain text. Do not add any meta-commentary or explanation.
</output_format>

"

SYSTEM_PROMPT_OPTIMIZE <- "

<system_role>
You are an expert Prompt Optimization Agent specializing in iterative refinement.
</system_role>

<task>
Your task is to optimize the <current_prompt> by integrating the provided <feedback>.
</task>

<context>
You will receive:
- <current_prompt>: The current version of the instruction.
- <source_materials>: The underlying task description and codebook.
- <feedback>: Specific human instructions for improvement.
</context>

<instructions>
- Modify only the parts of the prompt necessary to implement the .
- Preserve the original intent and functionality of the <current_prompt>.
- Keep all unrelated sections exactly the same.
- Maintain the original structure, section headers, and formatting of the prompt.
- Prefer small edits, insertions, or replacements rather than rewriting entire sections.
</instructions>

<output_format>
Return only the final revised prompt in plain text. 
Do NOT add any introductory headers that were not part of <current prompt>, such as '**Revised Prompt**'.
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
    max_tokens  = 4000
  )
)

# Instructor Modus 2: Prompt-Optimierung ---------------------------------------

hf_instructor_optimize <- ellmer::chat_huggingface(
  model = LLAMA_MODEL,
  system_prompt = SYSTEM_PROMPT_OPTIMIZE,
  credentials = function() API_KEY,
  echo = "none",
  params = list(
    temperature = 0.0, 
    max_tokens = 4000,  
    seed        = 12 
  )
)


# Für App Export: --------------------------------------------------------------

INSTRUCTOR_GENERATE_MODEL <- LLAMA_MODEL
INSTRUCTOR_GENERATE_PARAMS <- list(
  temperature = 0.0,
  max_tokens  = 4000
)

INSTRUCTOR_OPTIMIZE_MODEL <- LLAMA_MODEL
INSTRUCTOR_OPTIMIZE_PARAMS <- list(
  temperature = 0.0,
  max_tokens  = 4000,
  seed        = 12
)
