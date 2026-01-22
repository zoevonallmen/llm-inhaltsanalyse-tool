library(shiny) 
library(here)
source(here::here("R", "instructor.R"))


ui <- fluidPage(
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
        placeholder = "Art und Ziel der Analyse, etc."
      ),
      
      textAreaInput(
        "output_requirements",
        "Outputanforderung",
        rows = 4,
        placeholder = "JSON mit Feldern: code, reasoning"
      ),
      
      actionButton("lock_inputs", "Inputs übernehmen"),
      
      actionButton("run_instructor_generate", "Prompt generieren")
    ),
    
    mainPanel(
      #evt. später raus?
      h4("Prompt-Komponenten übernommen"),
      verbatimTextOutput("active_inputs"),
      
      #evt. später auch nicht anzeigen..
      h4("XML-Promptinputs für Instructor"),
      verbatimTextOutput("xml_prompt"),
      
      #Run Instructor Generate-Modus
      h4("Generierter Task Prompt"),
      verbatimTextOutput("instructor_generate_output")
    )
  )
)



server <- function(input, output, session) {
  
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
  
  #Anzeige übernommene Inputs für User
  output$active_inputs <- renderText({
    comps <- prompt_components()
    if(is.null(comps)) return("Noch keine Inputs übernommen.")
    
    paste0(
      "Task Description:\n", comps$task_description,
      "\n\nOutput Requirements:\n", comps$output_requirements,
      "\n\nCodebook: hochgeladen"
    )
  })
  
  #Generierung XML-Promptinputs für Instructor
  generate_instructor_prompt <- function(comps) {
    paste0(
      "<codebook>\n", comps$codebook, "\n</codebook>\n\n",
      "<task_description>\n", comps$task_description, "\n</task_description>\n\n",
      "<output_requirements>\n", comps$output_requirements, "\n</output_requirements>"
    )
  }
  
  #XMLPrompt anzeigen // evtl. später rausnehmen zum schauen obs funktioniert
  output$xml_prompt <- renderText({
    comps <- prompt_components()
    if(is.null(comps)) return("Noch keine Inputs übernommen.")
    generate_instructor_prompt(comps)
  })
  
  #Button: Prompt generieren (XML an instructor)
  observeEvent(input$run_instructor_generate, {
    comps <- prompt_components()
    req(comps)
    
    xml <- generate_instructor_prompt(comps)
    
    instructor_generated_prompt <- tryCatch(
      hf_instructor_generate$chat(xml, echo = "none"),
      error = function(e) paste("ERROR", e$message)
    )
    
    instructor_generate_out(instructor_generated_prompt)
    
  })
  
  #Instructor Output anzeigen
  output$instructor_generate_output <- renderText({
    out <- instructor_generate_out()
    if (is.null(out)) return("Noch nicht generiert.")
    out
  })
}



shinyApp(ui = ui, server = server) 