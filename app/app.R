library(shiny) 
library(shinythemes)
library(here)

source(here::here("R", "instructor.R"))
source(here::here("R", "classifier.R"))


ui <- fluidPage(
  theme = shinytheme("cyborg"),
  
  titlePanel("Inputs für Promptgenerierung"),
  
  sidebarLayout(
    sidebarPanel(
      
      fileInput(
        "codebook_file",
        "Codebuch hochladen",
        accept = c(".txt", ".md")
      ),
      
      textAreaInput(
        "task_description",
        "Aufgabenbeschrieb",
        rows = 4,
        placeholder = "Hier die Aufgabenbeschreibung eingeben..."
      ),
      
      textAreaInput(
        "output_requirements",
        "Outputanforderung",
        rows = 4,
        placeholder = "JSON mit Feldern: code, reasoning"
      ),
      
      actionButton("lock_inputs", "Inputs übernehmen"),
      
      actionButton("run_instructor_generate", "Prompt generieren"),
      
      tags$hr(),
      
      textAreaInput(
        "optimizer_feedback",
        "Feedback für Optimierung",
        rows = 4,
        placeholder = "Hier Feedback für die Prompt-Optimierung eingeben..."
      ),
      
      actionButton("run_instructor_optimize", "Prompt optimieren"),
      
      tags$hr(),
      
      selectInput(
        "prompt_for_classifier",
        "Prompt-Version für Klassifizierung auswählen",
        choices = character(0)
      ),
      
      tags$hr(),
      
      fileInput(
        "doc_files",
        "Textinputs hochladen (CSV)",
        accept = c(".csv") #sollten noch andere Formate erlaubt werden? 
      ),
      
      tags$hr(),
      
      fileInput(
        "subsample_file",
        "Codiertes Subsample ('Goldstandard') hochladen (CSV: doc_id, content, manual_code)",
        accept = c(".csv"),
      ),
      
      actionButton("lock_subsample", "Subsample übernehmen"),
      
      tags$hr(),
      
      actionButton("run_classifier", "Klassifizieren")
    ),
    
    mainPanel(
      #evt. später raus?
      h4("Prompt-Komponenten übernommen"),
      verbatimTextOutput("active_inputs"),
      
      #Run Instructor Generate-Modus
      h4("Aktuelle Task Prompt"),
      verbatimTextOutput("current_prompt"),
      
      h4("Klassifikation"),
      verbatimTextOutput("classifier_output"),
      tableOutput("classifier_table"),
      
      h4("Subsample Anzeige"),
      tableOutput("subsample_table")
      
    
      
    )
  )
)



server <- function(input, output, session) {
  
##INPUTS (Codebuch, Task Description, Output Requirements, Textinputs) ---------
  
  #Reactive Values für Prompt-Komponenten
  prompt_components <- reactiveVal(NULL)
  
  #Reactive Values (Speichern) für Instructor Generate Output
  instructor_generate_out <- reactiveVal(NULL)
  
  #Upload Codebook
  codebook_content <- reactive({
    req(input$codebook_file)
    readLines(input$codebook_file$datapath, encoding = "UTF-8")
  })
  
  #Button: Inputs übernehmen
  observeEvent(input$lock_inputs, {
    
    req(input$codebook_file) 
    
    prompt_components(list(
      codebook            = paste(codebook_content(), collapse = "\n"),
      task_description    = input$task_description,
      output_requirements = input$output_requirements
    ))
  })
  
  #Anzeige übernommene Inputs für User ==> kann dann evl später auch weg?
  output$active_inputs <- renderText({
    comps <- prompt_components()
    if(is.null(comps)) return("Noch keine Inputs übernommen.")
    
    paste0(
      "Task Description:\n", comps$task_description,
      "\n\nOutput Requirements:\n", comps$output_requirements,
      "\n\nCodebook: hochgeladen"
    )
  })
  
  
##PROMPTS IN XML TAGS (für Instructor Generate) --------------------------------
  
  #Generierung XML-Promptinputs für Instructor
  generate_instructor_prompt <- function(comps) {
    paste0(
      "<codebook>\n", comps$codebook, "\n</codebook>\n\n",
      "<task_description>\n", comps$task_description, "\n</task_description>\n\n",
      "<output_requirements>\n", comps$output_requirements, "\n</output_requirements>"
    )
  }


##VERSIONIERUNG DER PROMPTS ----------------------------------------------------
  
  prompt_versions <- reactiveVal(list())
  prompt_version_n <- reactiveVal(0)
  current_prompt_key <- reactiveVal(NULL)
  
  #neue Prompt als nächste Version speichern 
  save_new_version <- function(prompt_text) {
    n <- prompt_version_n() + 1
    key <- sprintf("v%02d", n)
    
    versions <- prompt_versions()
    versions[[key]] <- prompt_text
    
    prompt_versions(versions)
    prompt_version_n(n)
    current_prompt_key(key)
    
  }
  
  #current_prompz holen für Optimizer
  get_current_prompt <- function() {
    key <- current_prompt_key()
    req(key)
    
    versions <- prompt_versions()
    req(versions[[key]])
    
    versions[[key]]
  }
  
  #Dropdown für Prompt-Versionen im Classifier
  observe({
    versions <- prompt_versions()
    keys <- names(versions)
    
    updateSelectInput(
      session,
      "prompt_for_classifier",
      choices = keys,
      selected = current_prompt_key()
    )
  })
  
  #CSV einlesen
  docs_list <- reactive({
    req(input$doc_files)
    
    path <- input$doc_files$datapath
    df <- read.csv(path, stringsAsFactors = FALSE)
    
    if (!"content" %in% names(df)) {
      stop("CSV muss eine Spalte 'content' enthalten") #muss evtl. noch angepasst werden, wen nicht immer alle relevanten textspalten content heissen..
    }
    
    texts <- df$content
    texts <- texts[!is.na(texts) & nzchar(trimws(texts))]
    
    setNames(
      as.list(texts),
      paste0("row_", seq_along(texts))
    )
  })
  
  #Subsample
  active_subsample <- reactiveVal(NULL)
  

  
## Batch Klassifikation Ergebnisse speichern------------------------------------
  
  classifier_results <- reactiveVal(NULL)
  
##PROMPTS IN XML (für Instructor Optimize)--------------------------------------
  
  build_optimizer_input_xml <- function(current_prompt, comps, feedback) {
    source_materials_xml <- paste0(
      "<codebook>\n", comps$codebook, "\n</codebook>\n\n",
      "<task_description>\n", comps$task_description, "\n</task_description>\n\n",
      "<output_requirements>\n", comps$output_requirements, "\n</output_requirements>"
    )
    
    paste0(
      "<current_prompt>\n", current_prompt, "\n</current_prompt>\n\n",
      "<source_materials>\n", source_materials_xml, "\n</source_materials>\n\n",
      "<feedback>\n", feedback, "\n</feedback>"
    )
  }
  
##PROMPT GENERIERUNG (Instructor; Modus Generate) ------------------------------
  
  #Button: Prompt generieren (XML an instructor)
  observeEvent(input$run_instructor_generate, {
    comps <- prompt_components()
    req(comps)
    
    xml <- generate_instructor_prompt(comps)
    
    instructor_generated_prompt <- tryCatch(
      hf_instructor_generate$chat(xml, echo = "none"),
      error = function(e) paste("ERROR", e$message)
    )
    
    save_new_version(instructor_generated_prompt)
    
  })

##PROMPT OPTIMIERUNG (Instructor; Modus Optimize) ------------------------------
  
  observeEvent(input$run_instructor_optimize, {
    comps <- prompt_components()
    req(comps)
    
    feedback <- input$optimizer_feedback
    req(nzchar(feedback))
    
    current_prompt <- get_current_prompt()
    optimizer_input <- build_optimizer_input_xml(current_prompt, comps, feedback)
    
    optimized_prompt <- tryCatch(
      hf_instructor_optimize$chat(optimizer_input, echo = "none"),
      error = function(e) paste("ERROR", e$message)
    )
    
    save_new_version(optimized_prompt)
    
  })
  
##UPLOAD SUBSAMPLE UND VORSCHAU ------------------------------------------------
  observeEvent(input$lock_subsample, {
    df <- subsample_data()
    req(df)
    active_subsample(df)
  })

  
##KLASSIFIZIEREN ---------------------------------------------------------------
  
  observeEvent(input$run_classifier, {
    req(input$prompt_for_classifier)
    versions <- prompt_versions()
    prompt_key <- input$prompt_for_classifier
    prompt_text <- versions[[prompt_key]]
    req(prompt_text)
    
    docs <- docs_list()
    req(length(docs) > 0)
    
    withProgress(message = "Batch-Klassifikation läuft...", value = 0, {
      results <- lapply(seq_along(docs), function(i) {
        incProgress(1/length(docs), detail = paste("Dokument", i))
      
      article_text <- docs[[i]]
      
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
        
        res <- tryCatch(
          classifier(
            article_text = article_text,
            prompt = prompt_text,
            chat_object = hf_model
          ),
          error = function(e) list(
            success = FALSE, code = NA, reasoning = NA, raw = NA, json = NA, error = e$message
          )
        )
        
        end_time <- Sys.time()
        
        data.frame(
          row = i,
          prompt_version = prompt_key,
          success = isTRUE(res$success),
          code = if (is.null(res$code)) NA else as.character(res$code),
          reasoning = if (is.null(res$reasoning)) NA else as.character(res$reasoning),
          latency_s = as.numeric(difftime(end_time, start_time, units = "secs")),
          error = if (is.null(res$error)) NA else as.character(res$error),
          stringsAsFactors = FALSE
        )
      })
    })
    
    
    classifier_results(do.call(rbind, results))
    
    })
  
##AUSGABE GENERIERTER/OPTIMIERTER PROMPT (neuste Version) ----------------------
  output$current_prompt <- renderText({
    n <- prompt_version_n()
    key <- current_prompt_key()
    if (n == 0) return("Noch keine Prompt Version vorhanden")
    
    versions <- prompt_versions()
    prompt_text <- versions[[key]]
    
    paste0(
      "Aktuelle Prompt Version: ", key, "\n",
      "-------------------------\n",
      prompt_text
    )

  })
  

##OUPTPUT SUBSAMPLE ------------------------------------------------------------
  
  output$active_subsample <- renderText({
    df <- active_subsample()
    if (is.null(df)) return("Noch kein Subsample übernommen.")
    paste0("Aktives Subsample: ", nrow(df), " Zeilen") 
  })

##OUTPUT CLASSIFIER RESULTAT ---------------------------------------------------
  output$classifier_output <- renderText({
    df <- classifier_results()
    if (is.null(df)) return("Noch keine Klassifikation durchgeführt.")
    
    paste0(
      "Dokumente: ", nrow(df), "\n",
      "Erfolgreich: ", sum(df$success), "\n",
      "Fehler: ", sum(!df$success)
    )
  })
  
  output$classifier_table <- renderTable({
    df <- classifier_results()
    if (is.null(df)) return(NULL)
    df
  })
  


}





shinyApp(ui = ui, server = server) 