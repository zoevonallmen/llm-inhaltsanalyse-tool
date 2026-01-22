library(shiny) 


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
      
      actionButton("lock_inputs", "Inputs übernehmen")
    ),
    
    mainPanel(
      h4("Prompt-Komponenten übernommen"),
      verbatimTextOutput("active_inputs"),
      
      #evt. später auch nicht anzeigen..
      h4("XML-Promptinputs für Instructor"),
      verbatimTextOutput("xml_prompt")
    )
  )
)



server <- function(input, output, session) {
  
  #Reactive Values für Prompt-Komponenten
  prompt_components <- reactiveVal(NULL)
  
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
  
}



shinyApp(ui = ui, server = server) 