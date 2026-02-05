
## LIBRARIES -------------------------------------------------------------------
library(shiny) 
library(shinythemes)
library(here)

## LOAD KEY FUNCTIONS ----------------------------------------------------------
source(here::here("R", "instructor.R"))
source(here::here("R", "classifier.R"))

## UI --------------------------------------------------------------------------

ui <- fluidPage(
  theme = shinytheme("cyborg"),
  titlePanel("Inputs für Promptgenerierung"),
  
  sidebarLayout(
    sidebarPanel(
      
      # PROMPT INPUTS ----------------------------------------------------------
      
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
      
      # PROMPT OPTIMIZATION ----------------------------------------------------
      
      textAreaInput(
        "optimizer_feedback",
        "Feedback für Optimierung",
        rows = 4,
        placeholder = "Hier Feedback für die Prompt-Optimierung eingeben..."
      ),
      
      actionButton("run_instructor_optimize", "Prompt optimieren"),
      
      tags$hr(),
      
      # PROMPT SELECTION FOR CLASSIFIER ----------------------------------------
      
      selectInput(
        "prompt_for_classifier",
        "Prompt-Version für Klassifizierung auswählen",
        choices = character(0)
      ),
      
      tags$hr(),
      
      # SUBSAMPLE --------------------------------------------------------------
      
      fileInput(
        "subsample_file",
        "Codiertes Subsample ('Goldstandard') hochladen (CSV: doc_id, content, manual_code)",
        accept = c(".csv")
      ),
      
      selectInput("subsample_id_col", "ID-Spalte", choices = character(0)),
      selectInput("subsample_content_col", "Textspalte", choices = character(0)),
      selectInput("subsample_manual_col", "Manuelle Codierung/Goldstandard", choices = character(0)),
      
      checkboxInput("show_only_mismatches", "Nur Fehlcodierungen anzeigen", value = FALSE),
      
      actionButton("lock_subsample", "Subsample übernehmen"),
      actionButton("run_subsample_vitals", "Subsample testen (vitals)"),
      
      tags$hr(),
      
      # BATCH ------------------------------------------------------------------
      
      fileInput(
        "doc_files",
        "Textinputs hochladen (CSV)",
        accept = c(".csv") #sollten noch andere Formate erlaubt werden? 
      ),
      
      selectInput("batch_content_col", "Textspalte", choices = character(0)),
      selectInput("batch_id_col", "ID-Spalte", choices = character(0)),
      tags$hr(),
      
      numericInput("subsample_n", "Zufalls-Subsample (N)", value = 50, min = 1, step = 1),
      actionButton("draw_subsample", "Subsample ziehen"),
      downloadButton("download_subsample_template", "Subsample exportieren (CSV Template)"),
      
      actionButton("run_classifier", "Klassifizieren")
    ),
    
    mainPanel(
      #evt. später raus?
      h4("Prompt-Komponenten übernommen"),
      verbatimTextOutput("active_inputs"),
      
      h4("Prompts anzeigen"),
      selectInput("prompt_to_view", "Prompt-Version anzeigen", choices = character(0)),
      verbatimTextOutput("prompt_view"),
      
      h4("Subsample Anzeige"),
      tableOutput("subsample_table"),
      
      h4("Subsample Evaluation (vitals)"),
      verbatimTextOutput("eval_vitals_summary"),
      tableOutput("eval_vitals_table"),
      
      h4("Klassifikation"),
      verbatimTextOutput("classifier_output"),
      tableOutput("classifier_table")
    )
  )
)

## SERVER ----------------------------------------------------------------------

server <- function(input, output, session) {
  
  # REACTIVE VALUES ------------------------------------------------------------
  
  #Prompt-Komponenten
  prompt_components <- reactiveVal(NULL)
  
  #Instructor Generate Output
  instructor_generate_out <- reactiveVal(NULL)
  
  #Versionierung Prompts
  prompt_versions <- reactiveVal(list())
  prompt_version_n <- reactiveVal(0)
  current_prompt_key <- reactiveVal(NULL)
  
  #Subsample
  active_subsample <- reactiveVal(NULL)
  eval_vitals_df <- reactiveVal(NULL)
  eval_vitals_metrics <- reactiveVal(NULL)
  
  #Random Sample ziehen
  drawn_subsample <- reactiveVal(NULL)
  
  #Classifier Results
  classifier_results <- reactiveVal(NULL)
  
  # FUNKTIONEN -----------------------------------------------------------------
  
  #Generierung XML-Prompt-Inputs für Instructor (Generate)
  generate_instructor_prompt <- function(comps) {
    paste0(
      "<codebook>\n", comps$codebook, "\n</codebook>\n\n",
      "<task_description>\n", comps$task_description, "\n</task_description>\n\n",
      "<output_requirements>\n", comps$output_requirements, "\n</output_requirements>"
    )
  }
  
  #Neue Prompt als nächste Version speichern 
  save_new_version <- function(prompt_text) {
    n <- prompt_version_n() + 1
    key <- sprintf("v%02d", n)
    
    versions <- prompt_versions()
    versions[[key]] <- prompt_text
    
    prompt_versions(versions)
    prompt_version_n(n)
    current_prompt_key(key)
    
  }
  
  #Current_prompt holen für Optimizer
  get_current_prompt <- function() {
    key <- current_prompt_key()
    req(key)
    
    versions <- prompt_versions()
    req(versions[[key]])
    
    versions[[key]]
  }
  
  #Generierung XML-Prompt-Inputs für Instructor (Optimize)
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
  
  # REACTIVES (LOAD) -----------------------------------------------------------
  
  #Upload Codebook
  codebook_content <- reactive({
    req(input$codebook_file)
    readLines(input$codebook_file$datapath, encoding = "UTF-8")
  })
  
  #CSV Batch - Spaltenauswahl
  batch_df <- reactive({
    req(input$doc_files)
    
    path <- input$doc_files$datapath
    df <- read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
    req(nrow(df) > 0)
    df
  })
  
  #Upload CSV full Batch Classification
  docs_list <- reactive({
    
    df <- batch_df()
    req(input$batch_content_col)
    req(input$batch_content_col)
    
    content_col <- input$batch_content_col
    id_col <- input$batch_id_col
    
    if (!content_col %in% names(df)) {
      stop("Gewählte Textspalte existiert nicht im Datensatz.")
    }
    if (!id_col %in% names(df)) {
      stop("Gewählte ID-Spalte existiert nicht im Datensatz.")
    }
    
    content <- as.character(df[[content_col]])
    keep <- !is.na(content) & nzchar(trimws(content))
    df <- df[keep, , drop = FALSE]
    content <- content[keep]
    
    doc_id <- as.character(df[[id_col]])
    
    data.frame(
      doc_id = doc_id,
      content = content,
      stringsAsFactors = FALSE
    )
  })
  
  #CSV Subsample - Spaltenauswahl
  subsample_df <- reactive({
    req(input$subsample_file)
    
    path <- input$subsample_file$datapath
    
    header_line <- readLines(path, n = 1, encoding = "UTF-8", warn = FALSE)
    sep_guess <- if (grepl(";", header_line) && !grepl(",", header_line)) ";" else ","
    
    df <- tryCatch(
      read.csv(
        path,
        sep = sep_guess,
        stringsAsFactors = FALSE,
        check.names = FALSE,
        fileEncoding = "UTF-8"
      ),
      error = function(e) NULL
    )
    req(!is.null(df))
    req(nrow(df) > 0)
    
    names(df) <- trimws(names(df))
    
    if (ncol(df) == 1) {
      stop("Subsample-CSV wurde als 1 Spalte eingelesen.")
    }
    
    df
  })
  
  #Upload CSV Subsample
  subsample_data <- reactive({
    df <- subsample_df()
    
    req(input$subsample_id_col)
    req(input$subsample_content_col)
    req(input$subsample_manual_col)
    
    id_col <- input$subsample_id_col
    content_col <- input$subsample_content_col
    manual_col <- input$subsample_manual_col
    
    df$doc_id <- as.character(df[[id_col]])
    df$content <- as.character(df[[content_col]])
    df$manual_code <- as.character(df[[manual_col]])
    
    if (ncol(df) == 1) {
      stop(paste0(
        "CSV wurde als 1 Spalte eingelesen. Vermutlich falsches Trennzeichen/Export.\n",
        "Erkanntes Trennzeichen sep='", sep_guess, "'. Header:\n",
        header_line
      ))
    }
    
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
    
    df[, c("doc_id", "content", "manual_code")]
  })
  
  # OBSERVERS/EVENTS -----------------------------------------------------------
  
  #Prompt-Komponenten übernehmen
  observeEvent(input$lock_inputs, {
    
    req(input$codebook_file) 
    
    prompt_components(list(
      codebook            = paste(codebook_content(), collapse = "\n"),
      task_description    = input$task_description,
      output_requirements = input$output_requirements
    ))
  })
  
  #Generate Prompt (XML an instructor)
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
  
  #Optimize Prompt 
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
  
  #Dropdown für Prompt-Versionen
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
  
  #Dropdown für prompt_view
  observe({
    versions <- prompt_versions()
    keys <- names(versions)
    
    updateSelectInput(
      session,
      "prompt_to_view",
      choices = keys,
      selected = current_prompt_key()
    )
  })
  
  #Random Sample ziehen
  observeEvent(input$draw_subsample, {
    
    df <- docs_list()
    req(nrow(df) > 0)
    req(input$subsample_n)
    
    n_total <- nrow(df)
    n_take <- min(as.integer(input$subsample_n), n_total)
    
    set.seed(24) 
    idx <- sample(seq_len(n_total), size = n_take, replace = FALSE)
    
    drawn_subsample(df[idx, c("doc_id", "content")])
  })
  
  #Dropdowns mit Spaltennamen befüllen Subsample
  observeEvent(subsample_df(), {
    df <- subsample_df()
    cols <- names(df)
    
    default_id <- if ("doc_id" %in% cols) "doc_id" else cols[1]
    default_content <- if ("content" %in% cols) "content" else cols[1]
    default_manual <- if ("manual_code" %in% cols) "manual_code" else cols[1]
    
    updateSelectInput(session, "subsample_id_col", choices = cols, selected = default_id)
    updateSelectInput(session, "subsample_content_col", choices = cols, selected = default_content)
    updateSelectInput(session, "subsample_manual_col", choices = cols, selected = default_manual)
  })
  
  #Übernehmen Subsample
  observeEvent(input$lock_subsample, {
    df <- subsample_data()
    req(df)
    active_subsample(df)
  })
  
  #Subsample klassifizieren, Accuracy rechnen, Reasoning ausgeben
  observeEvent(input$run_subsample_vitals, {
    
    df <- active_subsample()
    req(df)
    req(nrow(df) > 0)
    
    req(input$prompt_for_classifier)
    versions <- prompt_versions()
    prompt_key <- input$prompt_for_classifier
    prompt_text <- versions[[prompt_key]]
    req(prompt_text)
    
    n <- nrow(df)
    
    norm_code <- function(x) {
      x <- as.character(x)
      x <- trimws(x)
      x[x == ""] <- NA_character_
      x
    }
    
    withProgress(message = "Subsample wird klassifiziert ...", value = 0, {
      
      out_list <- lapply(seq_len(n), function(i) {
        incProgress(1 / n, detail = paste("Dokument", i, "von", n))
        
        chat_obj <- ellmer::chat_huggingface(
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
            article_text = df$content[i],
            prompt = prompt_text,
            chat_object = chat_obj
          ),
          error = function(e) list(success = FALSE, code = NA, reasoning = NA, error = e$message)
        )
        
        pred <- norm_code(res$code)
        gold <- norm_code(df$manual_code[i])
        
        data.frame(
          doc_id      = as.character(df$doc_id[i]),
          manual_code = gold,
          pred_code   = pred,
          match       = !is.na(pred) && !is.na(gold) && pred == gold,
          reasoning   = if (is.null(res$reasoning)) NA_character_ else as.character(res$reasoning),
          stringsAsFactors = FALSE
        )
      })
      
    })
    
    out <- do.call(rbind, out_list)
    
    acc <- mean(out$match, na.rm = TRUE)# Accuracy selbst berechnen (nur gültige Vergleiche zählen)
    
    eval_vitals_df(out)
    eval_vitals_metrics(list(
      prompt_version = prompt_key,
      accuracy = acc
    ))
  })
  
  #Dropdowns mit Spaltennamen befüllen Batch 
  observeEvent(batch_df(), {
    df <- batch_df()
    cols <- names(df)
    
    default_content <- if ("content" %in% cols) "content" else cols[1]
    
    updateSelectInput(session, "batch_content_col",
                      choices = cols, selected = default_content)
    
    updateSelectInput(
      session,
      "batch_id_col",
      choices = cols,
      selected = if ("doc_id" %in% cols) "doc_id" else cols[1]
    )
    
  })
  
  #Full Batch Classify
  observeEvent(input$run_classifier, {
    req(input$prompt_for_classifier)
    versions <- prompt_versions()
    prompt_key <- input$prompt_for_classifier
    prompt_text <- versions[[prompt_key]]
    req(prompt_text)
    
    docs <- docs_list()
    req(nrow(docs) > 0)
    
    withProgress(message = "Batch-Klassifikation läuft...", value = 0, {
      n <- nrow(docs)
      results <- lapply(seq_len(n), function(i) {
        incProgress(1/n, detail = paste("Dokument", i, "von", n))
        
        article_text <- docs$content[i]
        doc_id <- as.character(docs$doc_id[i])
        
        chat_obj <- ellmer::chat_huggingface(
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
          doc_id = doc_id,
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
  
  # OUTPUTS --------------------------------------------------------------------
  
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
  
  #Prompt anzeigen für gewälte Version
  output$prompt_view <- renderText({
    versions <- prompt_versions()
    req(length(versions) > 0)
    
    key <- input$prompt_to_view
    req(key)
    prompt_text <- versions[[key]]
    req(prompt_text)
    
    paste0(
      "Prompt Version: ", key, "\n",
      "-------------------------\n",
      prompt_text
    )
  })
  
  #Anzeige uploaded Subsample (kann raus?)
  output$subsample_table <- renderTable({
    df <- active_subsample()
    if (is.null(df)) return(NULL)
    head(df, 50)
  })
  
  #Anzeigen Output Summary für Subsample
  output$eval_vitals_summary <- renderText({
    m <- eval_vitals_metrics()
    df <- eval_vitals_df()
    if (is.null(m) || is.null(df)) return("Noch keine Subsample Evaluation durchgeführt.")
    
    paste0(
      "Prompt-Version: ", m$prompt_version, "\n",
      "Textdocs: ", nrow(df), "\n",
      "Accuracy: ", round(as.numeric(m$accuracy), 3), "\n",
      "Fehlerhafte Codierungen: ", sum(df$match == FALSE, na.rm = TRUE)
    )
  })
  
  #Anzeigen Output Tabelle für Subsample
  output$eval_vitals_table <- renderTable({
    df <- eval_vitals_df()
    if (is.null(df)) return(NULL)
    
    if (isTRUE(input$show_only_mismatches)) {
      df <- df[df$match == FALSE, ]
    }
  
    subs <- active_subsample()
    if (!is.null(subs)) {
      df <- merge(df, subs[, c("doc_id", "content")], by = "doc_id", all.x = TRUE)
      df$content <- ifelse(
        is.na(df$content),
        NA,
        paste0(substr(df$content, 1, 200), ifelse(nchar(df$content) > 200, " ...", ""))
      )
    }
    
    df <- df[order(df$match, decreasing = TRUE), ]
    df[, c("doc_id", "manual_code", "pred_code", "match", "reasoning", "content")]
  })
  
  #Output Classifier Resultat
  output$classifier_output <- renderText({
    df <- classifier_results()
    if (is.null(df)) return("Noch keine Klassifikation durchgeführt.")
    
    paste0(
      "Dokumente: ", nrow(df), "\n",
      "Erfolgreich: ", sum(df$success), "\n",
      "Fehler: ", sum(!df$success)
    )
  })
  
  #Output Classifier Resultat Tabelle
  output$classifier_table <- renderTable({
    df <- classifier_results()
    if (is.null(df)) return(NULL)
    df
  })
  
  #Export Subsample
  output$download_subsample_template <- downloadHandler(
    filename = function() {
      paste0("subsample_template_", ".csv")
    },
    content = function(file) {
      df <- drawn_subsample()
      req(df)
      
      out <- df
      out$manual_code <- ""  #für manuelle codierung
      
      write.csv(out, file, row.names = FALSE, fileEncoding = "UTF-8")
    }
  )
  
  
}


shinyApp(ui = ui, server = server) 

