
## LIBRARIES -------------------------------------------------------------------
library(jsonlite)
library(shiny)
library(shinythemes)
library(here)
#lade ich schon im classifier, reicht?
# Dann würde es theoretisch reichen, wenn es aber wichtig für diesen Code ist, können
# Sie es ruhig auch hier laden. Das macht im Grunde keinen Unterschied. Sofern Sie
# alle Pakete immer zuerst laden, was Sie anscheinend im Sinne einer good practice tun -- super!
#
# Eine Alternative wäre, ein "globales" packages.R anzulegen und in alle Skripte zu laden.
# Das kann Sinn machen, wenn es eben primär um diese App geht und führt Sie näher an die Paketentwicklung heran.

## LOAD KEY FUNCTIONS ----------------------------------------------------------
source(here::here("R", "instructor.R"))
source(here::here("R", "classifier.R"))

# Toll, dass Sie here nutzen ;-)

## UI --------------------------------------------------------------------------

ui <- fluidPage(
  theme = shinytheme("cosmo"),
  titlePanel(""),

  sidebarLayout(
    sidebarPanel(

      # 1) INPUTS --------------------------------------------------------------
      tags$details(
        open = TRUE,
        tags$summary(tags$b("1. Inputs")),

        fileInput("codebook_file", "Codebuch hochladen (.txt, .md)", accept = c(".txt", ".md")),
        textAreaInput("task_description", "Aufgabenbeschrieb", rows = 3),
        textAreaInput("output_requirements", "Outputanforderung", rows = 3),
        actionButton("lock_inputs", "Inputs übernehmen"),

        tags$div(style="margin-top:8px; opacity:0.85;",
                 tags$small(tags$b("Status: ")),
                 textOutput("status_inputs_locked")
        )
      ),

      tags$hr(),

      # 2) PROMPTS -------------------------------------------------------------
      tags$details(
        open = TRUE,
        tags$summary(tags$b("2. Prompt-Entwicklung")),

        actionButton("run_instructor_generate", "Prompt generieren"),

        tags$hr(),
        tags$b("Feedback für Optimierung"),
        textAreaInput("optimizer_feedback", NULL, rows = 3,
                      placeholder = "Feedback formulieren und dann 'Feedback übernehmen' klicken..."),
        actionButton("lock_feedback", "Feedback übernehmen"),
        actionButton("run_instructor_optimize", "Prompt optimieren"),

        tags$div(style="margin-top:8px; opacity:0.85;",
                 tags$small(tags$b("Status: ")),
                 textOutput("status_feedback_locked")
        ),
        
        tags$hr(),
        tags$b("Begründung für Prompt-Änderung (nur für Dokumentation)"),
        textAreaInput("optimizer_rationale", NULL, rows = 2,
                      placeholder = "Warum wird der Prompt geändert? (wird nicht an LLM übergeben)"),
        actionButton("lock_rationale", "Begründung speichern"),
        
        tags$div(style="margin-top:8px; opacity:0.85;",
                 tags$small(tags$b("Status: ")),
                 textOutput("status_rationale_locked")
        ),

        tags$hr(),
        selectInput(
          "prompt_for_classifier",
          "Prompt-Version für Klassifizierung auswählen",
          choices = character(0)
        ),
        tags$div(style="margin-top:8px; opacity:0.85;",
                 tags$small(tags$b("Status: ")),
                 textOutput("status_prompt_for_classifier")
        )
      ),

      tags$hr(),

      # 3) SUBSAMPLE -----------------------------------------------------------
      tags$details(
        open = TRUE,
        tags$summary(tags$b("3. Subsample")),

        fileInput("subsample_file", "Goldstandard-Subsample (CSV)", accept = c(".csv")),
        selectInput("subsample_id_col", "ID-Spalte", choices = character(0)),
        selectInput("subsample_content_col", "Textspalte", choices = character(0)),
        selectInput("subsample_manual_col", "Manuelle Codierung", choices = character(0)),

        actionButton("lock_subsample", "Subsample übernehmen"),
        actionButton("run_subsample_vitals", "Subsample testen"),

        tags$div(style="margin-top:8px; opacity:0.85;",
                 tags$small(tags$b("Status: ")),
                 textOutput("status_subsample_locked")
        )
      ),

      tags$hr(),

      # 4) BATCH + SUBSAMPLE DRAW ---------------------------------------------
      tags$details(
        open = TRUE,
        tags$summary(tags$b("4. Batch-Klassifikation & Sample ziehen ")),

        fileInput("doc_files", "Datensatz (CSV)", accept = c(".csv")),
        selectInput("batch_content_col", "Textspalte", choices = character(0)),
        selectInput("batch_id_col", "ID-Spalte", choices = character(0)),

        tags$hr(),
        tags$b("Zufalls-Subsample ziehen"),
        numericInput("subsample_n", "N", value = 50, min = 1, step = 1),
        actionButton("draw_subsample", "Subsample ziehen"),
        downloadButton("download_subsample_template", "Subsample exportieren (Template)"),

        tags$div(style="margin-top:8px; opacity:0.85;",
                 tags$small(tags$b("Status: ")),
                 textOutput("status_drawn_subsample")
        ),

        tags$hr(),
        actionButton("run_classifier", "Batch klassifizieren")
      ),

      tags$hr(),

      # 5) EXPORT --------------------------------------------------------------
      tags$details(
        open = TRUE,
        tags$summary(tags$b("5. Export / Audit Trail")),
        downloadButton("download_audit_zip", "Audit Trail (ZIP)")
      )
    ),

    mainPanel(
      tabsetPanel(
        tabPanel(
          "Status",
          h4("Inputs Preview"),
          verbatimTextOutput("active_inputs"),
          tags$hr(),
          h4("Subsample Preview"),
          tableOutput("subsample_table"),
          h4("Batch-Status"),
          verbatimTextOutput("classifier_output")
        ),

        tabPanel(
          "Prompts",
          h4("Prompt auswählen"),
          selectInput("prompt_to_view", "Prompt-Version anzeigen", choices = character(0)),
          verbatimTextOutput("prompt_view") |> 
            tagAppendAttributes(style = "max-height:600px; overflow-y:auto;")
        ),

        tabPanel(
          "Subsample",
          h4("Evaluation"),
          selectInput("subsample_run_to_view", "Subsample-Run anzeigen", choices = character(0)),
          checkboxInput("show_only_mismatches", "Nur Fehlcodierungen anzeigen", value = FALSE),
          verbatimTextOutput("eval_vitals_summary"),
          tableOutput("eval_vitals_table")
        )
      )
    )
  )
)

# Ich fine, die UI sieht gut aus.


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

  #Feedback
  locked_feedback <- reactiveVal(NULL)
  
  #Begründung für Feedback
  locked_rationale <- reactiveVal(NULL)

  #Subsample
  active_subsample <- reactiveVal(NULL)

  subsample_runs <- reactiveVal(list())
  subsample_run_n <- reactiveVal(0)
  current_subsample_run_key <- reactiveVal(NULL)

  #Random Sample ziehen
  drawn_subsample <- reactiveVal(NULL)

  #Classifier Results
  classifier_results <- reactiveVal(NULL)

  batch_runs <- reactiveVal(list())
  batch_run_n <- reactiveVal(0)
  current_batch_run_key <- reactiveVal(NULL)

  #Logging
  process_log <- reactiveVal(list(
    meta = list(created_at = Sys.time()),
    inputs = NULL,
    prompt_events = list(),
    subsample_events = list(),
    batch_events = list()
  ))

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

  #Speicherung Subsample-Runs
  save_new_subsample_run <- function(out_df, prompt_key, acc) {
    n <- subsample_run_n() + 1
    key <- sprintf("run%02d", n)

    runs <- subsample_runs()
    runs[[key]] <- list(
      df = out_df,
      prompt_version = prompt_key,
      accuracy = acc
    )

    subsample_runs(runs)
    subsample_run_n(n)
    current_subsample_run_key(key)
  }

  #Speicherung Batch Classifications
  save_new_batch_run <- function(out_df, prompt_key) {
    n <- batch_run_n() + 1
    key <- sprintf("batch%02d", n)

    runs <- batch_runs()
    runs[[key]] <- list(
      df = out_df,
      prompt_version = prompt_key,
      created_at = Sys.time()
    )

    batch_runs(runs)
    batch_run_n(n)
    current_batch_run_key(key)
  }

  #Log Eintrag hinzufügen:
  add_log_event <- function(section, entry) {
    log <- process_log()
    if (is.null(log[[section]])) log[[section]] <- list()
    log[[section]][[length(log[[section]]) + 1]] <- entry
    process_log(log)
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
    
    header_line <- readLines(path, n = 1, encoding = "UTF-8", warn = FALSE)
    sep_guess <- if (grepl(";", header_line) && !grepl(",", header_line)) ";" else ","
    
    df <- tryCatch(
      read.csv(path, sep = sep_guess, stringsAsFactors = FALSE, check.names = FALSE, fileEncoding = "UTF-8"),
      error = function(e) NULL
    )
    req(!is.null(df))
    req(nrow(df) > 0)
    df
  })

  #Upload CSV full Batch Classification
  docs_list <- reactive({

    df <- batch_df()
    req(input$batch_content_col)
    req(input$batch_id_col)

    content_col <- input$batch_content_col
    id_col <- input$batch_id_col

    req(content_col %in% names(df))
    req(id_col %in% names(df))

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

    req(ncol(df) > 1) 

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

    req(id_col %in% names(df))     
    req(content_col %in% names(df)) 
    req(manual_col %in% names(df))  
    
    df$doc_id <- as.character(df[[id_col]])
    df$content <- as.character(df[[content_col]])
    df$manual_code <- as.character(df[[manual_col]])

    df <- df[!is.na(df$content) & nzchar(trimws(df$content)), ]
    df <- df[!is.na(df$manual_code) & nzchar(trimws(df$manual_code)), ]

    df[, c("doc_id", "content", "manual_code")]
  })

  # OBSERVERS/EVENTS -----------------------------------------------------------

  #Prompt-Komponenten übernehmen
  observeEvent(input$lock_inputs, {

    req(input$codebook_file)
    req(nzchar(trimws(input$task_description)))
    req(nzchar(trimws(input$output_requirements)))

    prompt_components(list(
      codebook            = paste(codebook_content(), collapse = "\n"),
      task_description    = input$task_description,
      output_requirements = input$output_requirements
    ))

    #loggen
    log <- process_log()
    log$inputs <- list(
      saved_at = Sys.time(),
      codebook = paste(codebook_content(), collapse = "\n"),
      task_description = input$task_description,
      output_requirements = input$output_requirements
    )
    process_log(log)

    add_log_event("prompt_events", list(
      type = "inputs_locked",
      at = Sys.time()
    ))

  })

  #Generate Prompt (XML an instructor)
  observeEvent(input$run_instructor_generate, {
    comps <- prompt_components()
    req(comps)

    xml <- generate_instructor_prompt(comps)

    #logggen
    add_log_event("prompt_events", list(
      type = "generate_request",
      at = Sys.time()
    ))

    instructor_generated_prompt <- tryCatch(
      hf_instructor_generate$chat(xml, echo = "none"),
      error = function(e) paste("ERROR", e$message)
    )

    save_new_version(instructor_generated_prompt)

    add_log_event("prompt_events", list(
      type = "generate_result",
      at = Sys.time(),
      new_prompt_key = current_prompt_key()
    ))

  })

  #Feedback übernehmen
  observeEvent(input$lock_feedback, {
    fb <- input$optimizer_feedback
    req(!is.null(fb))
    fb <- trimws(fb)
    req(nzchar(fb))

    locked_feedback(fb)
  })
  
  #Begründung speichern
  observeEvent(input$lock_rationale, {
    r <- trimws(input$optimizer_rationale)
    req(nzchar(r))
    locked_rationale(r)
  })

  #Optimize Prompt
  observeEvent(input$run_instructor_optimize, {
    comps <- prompt_components()
    req(comps)

    feedback <- locked_feedback()
    req(!is.null(feedback))
    req(nzchar(trimws(feedback)))

    current_prompt <- get_current_prompt()
    optimizer_input <- build_optimizer_input_xml(current_prompt, comps, feedback)

    add_log_event("prompt_events", list(
      type = "optimize_request",
      at = Sys.time(),
      feedback = feedback,
      rationale = locked_rationale(),
      base_prompt_key = current_prompt_key()
    ))

    hf_instructor_optimize_new <- ellmer::chat_huggingface(
      model = INSTRUCTOR_OPTIMIZE_MODEL,
      system_prompt = SYSTEM_PROMPT_OPTIMIZE,
      credentials = function() API_KEY,
      echo = "none",
      params = INSTRUCTOR_OPTIMIZE_PARAMS
    )
    
    optimized_prompt <- tryCatch(
      hf_instructor_optimize_new$chat(optimizer_input, echo = "none"),
      error = function(e) paste("ERROR", e$message)
    )

    save_new_version(optimized_prompt)

    add_log_event("prompt_events", list(
      type = "optimize_result",
      at = Sys.time(),
      new_prompt_key = current_prompt_key()
    ))

    locked_feedback(NULL)
    updateTextAreaInput(session, "optimizer_feedback", value = "")
    
    locked_rationale(NULL)
    updateTextAreaInput(session, "optimizer_rationale", value = "")

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
    df <- tryCatch(
      docs_list(),
      error = function(e) NULL
    )
    
    if (is.null(df)) {
      showNotification("Fehler beim Laden des Datensatzes – Spalten prüfen.", 
                       type = "error", duration = 5)
      return()
    }
    
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
    df <- tryCatch(
      subsample_df(),
      error = function(e) NULL
    )
    
    if (is.null(df)) {
      showNotification("Subsample-CSV konnte nicht gelesen werden – Trennzeichen prüfen.", 
                       type = "error", duration = 5)
      return()
    }
    
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
    df <- tryCatch(
      subsample_data(),
      error = function(e) NULL
    )
    
    if (is.null(df)) {
      showNotification("Fehler beim Laden des Subsamples – Spalten prüfen.", 
                       type = "error", duration = 5)
      return()
    }
    
    active_subsample(df)
  })
  
  
  #Dropdown für subsample_run_view
  observe({
    runs <- subsample_runs()
    keys <- names(runs)

    updateSelectInput(
      session,
      "subsample_run_to_view",
      choices = keys,
      selected = current_subsample_run_key()
    )
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

    save_new_subsample_run(out, prompt_key, acc)

    add_log_event("subsample_events", list(
      at = Sys.time(),
      run_key = current_subsample_run_key(),
      prompt_key = prompt_key,
      n_docs = nrow(out),
      accuracy = acc
    ))

  })

  #Dropdowns mit Spaltennamen befüllen Batch
  observeEvent(batch_df(), {
    df <- tryCatch(
      batch_df(),
      error = function(e) NULL
    )
    
    if (is.null(df)) {
      showNotification("Batch-CSV konnte nicht gelesen werden – Trennzeichen prüfen.", 
                       type = "error", duration = 5)
      return()
    }
    
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

    docs <- tryCatch(
      docs_list(),
      error = function(e) NULL
    )
    
    if (is.null(docs)) {
      showNotification("Fehler beim Laden des Datensatzes – Spalten prüfen.", 
                       type = "error", duration = 5)
      return()
    }
    
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
          doc_id = doc_id,
          #prompt_version = prompt_key, --> kann man thoer. rausnehmen, weil ist im audit (events.json)
          success = isTRUE(res$success),
          code = if (is.null(res$code)) NA else as.character(res$code),
          #reasoning = if (is.null(res$reasoning)) NA else as.character(res$reasoning), -> evtl auch raus, könnte zu viel werden, bei grossen textmengen. ausser noch nachträglich validieren?
          #latency_s = as.numeric(difftime(end_time, start_time, units = "secs")), -> is des nötig?
          stringsAsFactors = FALSE
        )
      })
    })

    out <- do.call(rbind, results)
    classifier_results(out)
    save_new_batch_run(out, prompt_key)

    add_log_event("batch_events", list(
      at = Sys.time(),
      run_key = current_batch_run_key(),
      prompt_key = prompt_key,
      n_docs = nrow(out),
      n_success = sum(out$success)
    ))

  })

  # OUTPUTS --------------------------------------------------------------------

  # Anzeige übernommene Inputs für User ==> kann dann evl später auch weg?
  # Oder Sie machen es optional.

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

  # Anzeige uploaded Subsample (kann raus?)
  # Wie gesgat, eventuell könnten Sie es auch als Opion im Sinne der Transparenz anbieten.
  # Anonsten ist es natürlich kein Muss und kann raus.
  output$subsample_table <- renderTable({
    df <- active_subsample()
    if (is.null(df)) return(NULL)
    head(df, 50)
  })

  # Anzeigen Output Summary für Subsample
  output$eval_vitals_summary <- renderText({
    runs <- subsample_runs()
    if (length(runs) == 0) return("Noch keine Subsample Evaluation durchgeführt.")

    key <- input$subsample_run_to_view
    if (is.null(key) || !nzchar(key)) key <- current_subsample_run_key()
    req(key)

    run <- runs[[key]]
    df <- run$df
    req(!is.null(df))

    paste0(
      "Run: ", key, "\n",
      "Prompt-Version: ", run$prompt_version, "\n",
      "Textdocs: ", nrow(df), "\n",
      "Accuracy: ", round(as.numeric(run$accuracy), 3), "\n",
      "Fehlerhafte Codierungen: ", sum(df$match == FALSE, na.rm = TRUE)
    )
  })

  # Anzeigen Output Tabelle für Subsample
  output$eval_vitals_table <- renderTable({
    runs <- subsample_runs()
    if (length(runs) == 0) return(NULL)

    key <- input$subsample_run_to_view
    if (is.null(key) || !nzchar(key)) key <- current_subsample_run_key()
    req(key)

    df <- runs[[key]]$df
    req(!is.null(df))

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

  # Output Classifier Resultat
  output$classifier_output <- renderText({
    df <- classifier_results()
    if (is.null(df)) return("Noch keine Klassifikation durchgeführt.")

    run_key <- current_batch_run_key()
    runs <- batch_runs()
    rk <- current_batch_run_key()
    pv <- if (!is.null(rk) && rk %in% names(runs)) runs[[rk]]$prompt_version else "-"

    paste0(
      "Batch-Run: ", ifelse(is.null(run_key), "-", run_key), "\n",
      "Dokumente: ", nrow(df), "\n",
      "Prompt-Version: ", pv, "\n",
      "Erfolgreich: ", sum(df$success), "\n",
      "Export bereit."
    )
  })


  # Export Randomsample
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

  # STATUS
  # Status: Inputs übernommen?
  output$status_inputs_locked <- renderText({
    comps <- prompt_components()
    if (is.null(comps)) "Noch nicht übernommen"
    else "Inputs übernommen"
  })

  # Status: Feedback übernommen?
  output$status_feedback_locked <- renderText({
    fb <- locked_feedback()
    if (is.null(fb) || !nzchar(trimws(fb))) "Feedback noch nicht übernommen"
    else "Feedback übernommen (bereit für Optimierung)"
  })
  
  #Status: Begründung gespeichert?
  output$status_rationale_locked <- renderText({
    r <- locked_rationale()
    if (is.null(r) || !nzchar(trimws(r))) "Begründung noch nicht gespeichert"
    else "Begründung gespeichert"
  })

  # Status: Subsample übernommen?
  output$status_subsample_locked <- renderText({
    df <- active_subsample()
    if (is.null(df) || nrow(df) == 0) "Noch kein Subsample übernommen"
    else paste0("Subsample übernommen (n = ", nrow(df), ")")
  })

  # Status: Zufalls-Subsample gezogen?
  output$status_drawn_subsample <- renderText({
    df <- drawn_subsample()
    if (is.null(df) || nrow(df) == 0) "Noch kein Subsample gezogen"
    else paste0("Subsample gezogen (n = ", nrow(df), ") – Export möglich")
  })

  # status output prompt for classify
  output$status_prompt_for_classifier <- renderText({
    v <- prompt_versions()
    if (length(v) == 0) return("Noch keine Prompt-Version vorhanden (erst generieren).")

    sel <- input$prompt_for_classifier
    if (is.null(sel) || !nzchar(sel)) "Keine Prompt-Version ausgewählt"
    else paste0("Ausgewählt: ", sel)
  })

  # EXPORT ZIP
  output$download_audit_zip <- downloadHandler(
    filename = function() {
      paste0("llm_audit_trail_", Sys.Date(), ".zip")
    },
    content = function(file) {

      log <- process_log()
      
      if (is.null(log$inputs)) {
        showNotification("Inputs fehlen – zuerst Inputs übernehmen.", 
                         type = "error", duration = 5)
        return(NULL)
      }
      
      if (length(prompt_versions()) == 0) {
        showNotification("Keine Prompt-Version vorhanden.", 
                         type = "error", duration = 5)
        return(NULL)
      }
      
      root <- tempfile("audit_")
      dir.create(root, recursive = TRUE)

      dir_system    <- file.path(root, "00_system")
      dir_inputs    <- file.path(root, "01_inputs")
      dir_prompts   <- file.path(root, "02_prompts")
      dir_events    <- file.path(root, "03_events")
      dir_subsample <- file.path(root, "04_subsample_runs")
      dir_batch     <- file.path(root, "05_batch_runs")
      dir.create(dir_system); dir.create(dir_inputs); dir.create(dir_prompts); dir.create(dir_events)
      dir.create(dir_subsample); dir.create(dir_batch)

      # metadata
      if (exists("SYSTEM_PROMPT_CLASSIFIER")) {
        writeLines(SYSTEM_PROMPT_CLASSIFIER, file.path(dir_system, "system_prompt_classifier.txt"), useBytes = TRUE)
      }
      if (exists("SYSTEM_PROMPT_GENERATE")) {
        writeLines(SYSTEM_PROMPT_GENERATE, file.path(dir_system, "system_prompt_instructor_generate.txt"), useBytes = TRUE)
      }
      if (exists("SYSTEM_PROMPT_OPTIMIZE")) {
        writeLines(SYSTEM_PROMPT_OPTIMIZE, file.path(dir_system, "system_prompt_instructor_optimize.txt"), useBytes = TRUE)
      }

      meta_export <- list(
        exported_at = Sys.time(),

        classifier = list(
          model = if (exists("CLASSIFIER_MODEL")) CLASSIFIER_MODEL else NA,
          params = if (exists("CLASSIFIER_PARAMS")) CLASSIFIER_PARAMS else NA
        ),

        instructor_generate = list(
          model = if (exists("INSTRUCTOR_GENERATE_MODEL")) INSTRUCTOR_GENERATE_MODEL else NA,
          params = if (exists("INSTRUCTOR_GENERATE_PARAMS")) INSTRUCTOR_GENERATE_PARAMS else NA
        ),

        instructor_optimize = list(
          model = if (exists("INSTRUCTOR_OPTIMIZE_MODEL")) INSTRUCTOR_OPTIMIZE_MODEL else NA,
          params = if (exists("INSTRUCTOR_OPTIMIZE_PARAMS")) INSTRUCTOR_OPTIMIZE_PARAMS else NA
        )
      )

      jsonlite::write_json(
        meta_export,
        file.path(dir_system, "model_and_params.json"),
        pretty = TRUE,
        auto_unbox = TRUE
      )

      # inputs
      writeLines(log$inputs$codebook, file.path(dir_inputs, "codebook.txt"), useBytes = TRUE)
      writeLines(as.character(log$inputs$task_description), file.path(dir_inputs, "task_description.txt"), useBytes = TRUE)
      writeLines(as.character(log$inputs$output_requirements), file.path(dir_inputs, "output_requirements.txt"), useBytes = TRUE)

      # prompt versionen
      pv <- prompt_versions()
      for (k in names(pv)) {
        writeLines(as.character(pv[[k]]), file.path(dir_prompts, paste0("prompt_", k, ".txt")), useBytes = TRUE)
      }
      # Die Schleife könnte man im Sinne der Performance optimieren, muss aber nicht sein.

      #Events/history
      jsonlite::write_json(log, file.path(dir_events, "events.json"),
                           pretty = TRUE, auto_unbox = TRUE)

      #subsample runs/eval
      sr <- subsample_runs()
      if (length(sr) > 0) {
        for (rk in names(sr)) {
          df <- sr[[rk]]$df
          write.csv(df, file.path(dir_subsample, paste0("subsample_", rk, ".csv")),
                    row.names = FALSE, fileEncoding = "UTF-8")
        }
      }

      #batch resultate
      br <- batch_runs()
      if (length(br) > 0) {
        for (rk in names(br)) {
          df <- br[[rk]]$df
          write.csv(df, file.path(dir_batch, paste0(rk, ".csv")),
                    row.names = FALSE, fileEncoding = "UTF-8")
        }
      }

      #ZIP
      old <- getwd()
      setwd(root)
      on.exit(setwd(old), add = TRUE)

      files_to_zip <- list.files(root, recursive = TRUE, full.names = FALSE)
      utils::zip(zipfile = file, files = files_to_zip)
    }
  )

}


shinyApp(ui = ui, server = server)

# Eine tolle App!
