# Shiny App for Bayesian Coverage Analysis
# Takes in country data and outputs estimates in a CSV

# Load Libraries
library(shiny)
library(bayescoveragemodel)
library(localhierarchy) # for check_nas...
library(tidyverse)
library(ggplot2)
library(haven)
library(brms) # brms required for routine stuff
options(cmdstanr_warn_inits = FALSE)



# Data folder
data_folder <- "data_raw"
# data folder contains survey data "ICEH_all.long.dta"
# and a dummy data set for routine data (routine_toydata.csv)


# Indicators that support routine data
indicator_routine <- c("anc1trimester", "vmsl", "ideliv", "vdpt", "anc4")

# All available indicators
indicator_all <-   c("anc1trimester", "vmsl", "ideliv", "vdpt", "anc4",
                     "bfexcl0_5", "ancq8" , "cci" , "sba" )


# UI
ui <- fluidPage(
  titlePanel("Bayesian Coverage Analysis"),

  sidebarLayout(
    sidebarPanel(
      # Data source selection
      radioButtons("data_source", "Data Source:",
                   choices = c("Use existing data" = "existing",
                               "Upload file" = "upload")),

      # Conditional file upload
      conditionalPanel(
        condition = "input.data_source == 'upload'",
        fileInput("data_file", "Upload Data File (.dta or .csv):",
                  accept = c(".dta", ".csv"))
      ),

      # Indicator selection
      selectInput("indicator", "Select Indicator:",
                  choices = indicator_all,
                  selected = "anc4"),

      # ISO code input
      textInput("iso_code", "Enter ISO Country Code:",
                value = "KEN",
                placeholder = "e.g., KEN, NGA, ETH"),

      # Routine data checkbox (conditional on indicator selection)
      conditionalPanel(
        condition = "['anc1trimester', 'vmsl', 'ideliv', 'vdpt', 'anc4'].includes(input.indicator)",
        checkboxInput("add_routine", "Add Routine Data", value = FALSE)
      ),

      # Run button
      actionButton("run_model", "Run Model", class = "btn-primary"),

      hr(),

      # Download button (only shown after model runs)
      conditionalPanel(
        condition = "output.model_complete",
        downloadButton("download_csv", "Download Estimates (CSV)")
      )
    ),

    mainPanel(
      # Status message
      verbatimTextOutput("status"),

      # Plot output
      plotOutput("estimate_plot", height = "600px"),

      # Estimates table preview
      h4("Estimates Preview:"),
      tableOutput("estimates_table")
    )
  )
)

# Server
server <- function(input, output, session) {

  # Reactive values to store results
  rv <- reactiveValues(
    fit_local = NULL,
    model_complete = FALSE
  )

  # Load data based on source selection
  data_raw <- reactive({
    if (input$data_source == "existing") {
      dat <- read_dta(here::here(data_folder, "ICEH_all.long.dta")) %>%
        rename(r = r_raw, se = se_raw)
      return(dat)
    } else {
      req(input$data_file)
      file_ext <- tools::file_ext(input$data_file$datapath)

      if (file_ext == "dta") {
        dat <- read_dta(input$data_file$datapath) %>%
          rename(r = r_raw, se = se_raw)
      } else if (file_ext == "csv") {
        dat <- read_csv(input$data_file$datapath, show_col_types = FALSE)
      } else {
        stop("Unsupported file format. Please upload .dta or .csv")
      }
      return(dat)
    }
  })

  # Run model when button clicked
  observeEvent(input$run_model, {
    req(input$iso_code)

    rv$model_complete <- FALSE
    rv$fit_local <- NULL

    # Show progress
    withProgress(message = 'Fitting model...', value = 0, {

      tryCatch({
        indicator_select <- input$indicator
        iso_select <- toupper(trimws(input$iso_code))

        incProgress(0.1, detail = "Loading data...")

        dat0 <- data_raw()

        # Read global fit
        incProgress(0.2, detail = "Loading global fit...")

        incProgress(0.3, detail = "Processing survey data...")

        # Process survey data
        dat <- process_data(
          dat = dat0,
          regions_dat = bayescoveragemodel::regions_all,
          indicator = indicator_select
        )


        # Check if ISO exists in data
        if (!iso_select %in% unique(dat$iso)) {
          stop(paste("ISO code", iso_select, "not found in data. Available codes:",
                     paste(head(unique(dat$iso), 20), collapse = ", ")))
        }

        incProgress(0.4, detail = "Fitting local model (this may take a few minutes)...")

        # Handle routine data
        routine_dat_use <- NULL
        if (isTRUE(input$add_routine) && indicator_select %in% indicator_routine) {
          routine_dat_use <- read_csv(here::here("data_raw/routine_toydata.csv"), show_col_types = FALSE) %>%
            mutate(iso = iso_select,
                   indicator_name = case_when(
                     indicator_select == "anc1trimester" ~ "anc",
                     indicator_select == "vmsl" ~ "measles2",
                     indicator_select == "ideliv" ~ "instdeliveries",
                     indicator_select == "vdpt" ~ "penta3",
                     indicator_select == "anc4" ~ "anc4"
                   ))
        }


        fit_local <- fit_model(
          runstep = "local_national",
          y = "invprobit_indicator",
          se = "se_invprobit_indicator",
          survey_df = dat %>% filter(iso %in% iso_select),
          routine_data = routine_dat_use,
          chains = 4,
          iter_sampling = 300,
          iter_warmup = 150,
          get_posteriors = TRUE
        )


        incProgress(1.0, detail = "Complete!")

        rv$fit_local <- fit_local
        rv$model_complete <- TRUE


      }, error = function(e) {
        showNotification(paste("Error:", e$message), type = "error", duration = 10)
      })
    })
  })

  # Output: model complete flag for conditional panel
  output$model_complete <- reactive({
    rv$model_complete
  })
  outputOptions(output, "model_complete", suspendWhenHidden = FALSE)

  # Output: Status message
  output$status <- renderText({
    if (is.null(rv$fit_local)) {
      "Ready. Select options and click 'Run Model' to start."
    } else {
      paste("Model fitting complete for", toupper(input$iso_code), "-", input$indicator)
    }
  })

  # Output: Plot
  output$estimate_plot <- renderPlot({
    req(rv$fit_local)
    plot_estimates_local_all(results = rv$fit_local)
  })




  # Output: Estimates table preview
  output$estimates_table <- renderTable({
    req(rv$fit_local)
    head( rv$fit_local$posterior$temporal %>%
            rename(estimate = `50%`,
                   lower_95 =`2.5%`,,
                   upper_95 = `97.5%`) %>%
            select(year, estimate, lower_95, upper_95)
          , 10)
  })

  # Download handler for CSV
  output$download_csv <- downloadHandler(
    filename = function() {
      paste0("estimates_", input$indicator, "_", input$iso_code, "_", Sys.Date(), ".csv")
    },
    content = function(file) {
      req(rv$fit_local)
      write_csv(rv$fit_local$posterior$temporal %>%
                  rename(estimate = `50%`,
                         lower_95 =`2.5%`,,
                         upper_95 = `97.5%`) %>%
                  select(year, estimate, lower_95, upper_95), file)
    }
  )
}

# Run the app
shinyApp(ui = ui, server = server)
