library(shiny) 
library(shinythemes)
library(vitals)
library(tibble)
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
        accept = c(".csv")
      ),
      
      actionButton("lock_subsample", "Subsample übernehmen"),
      
      actionButton("run_subsample_vitals", "Subsample testen (vitals)"),
      
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
      
      h4("Subsample Anzeige"),
      tableOutput("subsample_table"),
      
      h4("Subsample Evaluation (vitals)"),
      verbatimTextOutput("eval_vitals_summary"),
      tableOutput("eval_vitals_table"),
      
      h4("Klassifikation"),
      verbatimTextOutput("classifier_output"),
      tableOutput("classifier_table"),
      
      
    
      
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
  
  eval_vitals_df <- reactiveVal(NULL)
  eval_vitals_metrics <- reactiveVal(NULL)
  
  #Subsample CSV:
  subsample_data <- reactive({
    req(input$subsample_file)

    df <- tryCatch(
      read.csv(input$subsample_file$datapath, stringsAsFactors = FALSE),
      error = function(e) NULL
    )
    
    # Spalten prüfen
    required <- c("doc_id", "content", "manual_code")
    missing <- setdiff(required, names(df))
    if (length(missing) > 0) {
      stop(paste0(
        "Subsample-CSV fehlt Spalte(n): ",
        paste(missing, collapse = ", "),
        "\nGefundene Spalten: ",
        paste(names(df), collapse = ", ")
      ))
    }
    
    df <- df[!is.na(df$content) & nzchar(trimws(df$content)), ]
    df <- df[!is.na(df$manual_code) & nzchar(trimws(df$manual_code)), ]
    
    df
  })
  
  
  

  
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


  
##VITALS-FUNKTIONEN: SOLVER, SCORER, METRICS -----------------------------------
  
  #SOLVER (solver ruft classifier auf)
  solver_classifier <- function(input, prompt_text) {
    #input = texte (content) / prompt_text = ausgewählte Prompt-Version
    
    results <- lapply(seq_along(input), function(i) {
      
      chat_obj <- hf_model <- ellmer::chat_huggingface(
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
      
      res <- tryCatch(
        classifier(
          article_text = input[[i]],
          prompt = prompt_text,
          chat_object = chat_obj
        ),
        error = function(e) list(
          success = FALSE, code = NA, reasoning = NA, raw = NA, json = NA, error = e$message
        )
      )
      
      list(
        pred_code = if (is.null(res$code)) NA_character_ else as.character(res$code),
        reasoning = if (is.null(res$reasoning)) NA_character_ else as.character(res$reasoning),
        success = isTRUE(res$success),
        error = if (is.null(res$error)) NA_character_ else as.character(res$error)
      )
    })
    
    list(
      result    = vapply(results, `[[`, "", "pred_code"),
      reasoning = vapply(results, `[[`, "", "reasoning"),
      success   = vapply(results, `[[`, FALSE, "success"),
      error     = vapply(results, `[[`, "", "error")
    )
  }
  
  #SCORER (result gegeb target matchen)
  scorer_exact_match <- function(result, target) {
    #result & target = character vektore, gleiche länge
    #scorer soll pro sample artikel 1 Label liefern ("C" = correct, "F" = false)
    ifelse(!is.na(result) & result == target, "C", "I") 
  }
  
  #METRICS: ACCURACY
  metric_accuracy <- function(score) {
    mean(score =="C", na.rm = TRUE)
  }
  
##SUBSAMLPLE -------------------------------------------------------------------
  
  #Upload/Übernehmen Subsample
  observeEvent(input$lock_subsample, {
    df <- subsample_data()
    req(df)
    active_subsample(df)
  })
  
  #Button: Task bauen/ausführen (Subsample klassifizieren, vitals Analysis)
  observeEvent(input$run_subsample_vitals, {
    
    df <- active_subsample()
    req(df)
    req(nrow(df) > 0)
    
    req(input$prompt_for_classifier)
    versions <- prompt_versions()
    prompt_key <- input$prompt_for_classifier
    prompt_text <- versions[[prompt_key]]
    req(prompt_text)
    
    
    #vitals Dataset, min. inkl. input und target
    dataset_vitals <- tibble::tibble(
      input = as.character(df$content),
      target = as.character(df$manual_code),
      doc_id = as.character(df$doc_id) #so fürs vergleichen noch gut?
    )
    
    task <- vitals::Task$new(
      dataset = dataset_vitals,
      solver = solver_classifier,
      scorer = scorer_exact_match,
      metrics = list(accuracy = metric_accuracy),
      name = paste0("subsample_", prompt_key)
    )
    
    #$eval
    task$eval(prompt_text = prompt_text, view = FALSE) #view optinoal, mal ausprobieren wenns sonst klappt..
    
    samples <- task$get_samples() #enthält input, target, reult, score usw
    metrics <- task$metrics #list mit accuracy
    
    #tabelle für UI hier bauen?
    out <- data.frame(
      doc_id = samples$doc_id,
      manual_code = samples$target,
      pred_code = samples$result,
      match = samples$score == "C",
      reasoning = samples$reasoning,
      success = samples$success,
      error = samples$error,
      stringsAsFactors = FALSE
    )
    
    eval_vitals_df(out)
    eval_vitals_metrics(list(
      prompt_version = prompt_key,
      accuracy = metrics[["accuracy"]]
    ))
    
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
      
      chat_obj <- hf_model <- ellmer::chat_huggingface(
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
        
        start_time <- Sys.time() #kann eigentlich jetzt raus?
        
        res <- tryCatch(
          classifier(
            article_text = article_text,
            prompt = prompt_text,
            chat_object = chat_obj
          ),
          error = function(e) list(
            success = FALSE, code = NA, reasoning = NA, raw = NA, json = NA, error = e$message
          )
        )
        
        end_time <- Sys.time() #raus? 
        
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
  
  #Anzeige Subsample (kann raus?)
  output$active_subsample <- renderText({
    df <- active_subsample()
    if (is.null(df)) return("Noch kein Subsample übernommen.")
    paste0("Aktives Subsample: ", nrow(df), " Zeilen") 
  })
  
  output$subsample_table <- renderTable({
    df <- active_subsample()
    if (is.null(df)) return(NULL)
    head(df, 50)
  })
  
  
  #Anzeigen Outpuut Summary, tabelle
  output$eval_vitals_summary <- renderText({
    m <- eval_vitals_metrics()
    df <- eval_vitals_df()
    if (is.null(m) || is.null(df)) return("Noch keine Subsample Evaluation durchgeführt.")
    
    paste0(
      "Prompt-Version: ", m$prompt_version, "\n",
      "Textdoc: ", nrow(df), "\n",
      "Accuracy: ", round(as.numeric(m$accuracy), 3), "\n",
      "Fehlerhafte Runs: ", sum(!df$success)
    )
  })
  
  output$eval_vitals_table <- renderTable({
    df <- eval_vitals_df()
    if (is.null(df)) return(NULL)
    
    df[order(df$match, decreasing = TRUE), c("doc_id", "manual_code", "pred_code", "match", "reasoning")]
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

