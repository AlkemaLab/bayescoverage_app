# Shiny App for Bayesian Coverage Analysis
# Takes in country data and outputs estimates in a CSV

# # Installation instructions are in readme, copied here
# devtools::install_github("AlkemaLab/bayescoveragemodel")
# devtools::install_github("AlkemaLab/localhierarchy")
# install.packages('bayescoveragedeploy',
#                  repos = c('https://alkemalab.r-universe.dev'))
# install.packages(c("dplyr", "haven", "ggplot2", "shiny",  "readr", "here", "stringr",
#    "tibble"))
# # For using routine data, `brms` is used as well, install using
# install.packages("brms")

# Load Libraries
library(shiny)
library(bayescoveragedeploy)

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

      # Routine data source selection
      conditionalPanel(
        condition = "input.add_routine == true && ['anc1trimester', 'vmsl', 'ideliv', 'vdpt', 'anc4'].includes(input.indicator)",
        radioButtons("routine_source", "Routine Data Source:",
                     choices = c("Use existing data (dummy)" = "existing",
                                 "Upload file" = "upload"),
                     selected = "existing")
      ),

      # Conditional file upload for routine data
      conditionalPanel(
        condition = "input.add_routine == true && input.routine_source == 'upload' && ['anc1trimester', 'vmsl', 'ideliv', 'vdpt', 'anc4'].includes(input.indicator)",
        fileInput("routine_file", "Upload Routine Data (.csv):",
                  accept = c(".csv")),
        helpText("Expected format: iso, year, routine_value, routine_roc, worst_combi, sd_routine_roc, sd_routine, indicator_name, indicator")
      ),

      # Run button
      actionButton("run_model", "Run Model", class = "btn-primary"),

      # Start over button
      actionButton("start_over", "Start Over", class = "btn-warning"),

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
      dat <- haven::read_dta(here::here(data_folder, "ICEH_all.long.dta")) |>
        dplyr::rename(r = r_raw, se = se_raw)
      return(dat)
    } else {
      req(input$data_file)
      file_ext <- tools::file_ext(input$data_file$datapath)

      if (file_ext == "dta") {
        dat <- haven::read_dta(input$data_file$datapath) |>
          dplyr::rename(r = r_raw, se = se_raw)
      } else if (file_ext == "csv") {
        dat <- readr::read_csv(input$data_file$datapath, show_col_types = FALSE)
      } else {
        stop("Unsupported file format. Please upload .dta or .csv")
      }
      return(dat)
    }
  })

  # Start over when button clicked
  observeEvent(input$start_over, {
    rv$fit_local <- NULL
    rv$model_complete <- FALSE
    showNotification("Results cleared. Ready to run a new model.", type = "message", duration = 3)
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
        dat <- bayescoveragemodel::process_data(
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
          # Read routine data based on source
          if (input$routine_source == "upload") {
            # Use uploaded file
            req(input$routine_file)

            # Read uploaded routine data
            routine_dat_raw <- readr::read_csv(input$routine_file$datapath,
                                        show_col_types = FALSE)

            # Validate columns
            required_cols <- c("year", "routine_value", "routine_roc", "worst_combi",
                             "sd_routine_roc", "sd_routine")
            missing_cols <- setdiff(required_cols, names(routine_dat_raw))

            if (length(missing_cols) > 0) {
              stop(paste("Uploaded routine data is missing required columns:",
                        paste(missing_cols, collapse = ", ")))
            }
          } else {
            # Use existing (dummy) routine data
            routine_dat_raw <- readr::read_csv(here::here("data_raw/routine_toydata.csv"),
                                        show_col_types = FALSE)
          }

          # Apply common transformations
          routine_dat_use <- routine_dat_raw |>
            dplyr::mutate(iso = iso_select,
                   indicator_name = dplyr::case_when(
                     indicator_select == "anc1trimester" ~ "anc",
                     indicator_select == "vmsl" ~ "measles2",
                     indicator_select == "ideliv" ~ "instdeliveries",
                     indicator_select == "vdpt" ~ "penta3",
                     indicator_select == "anc4" ~ "anc4"
                   ))
        }


        fit_local <- fit_local_model(
          survey_df = dat |> dplyr::filter(iso %in% iso_select),
          iso_select  = iso_select,
          routine_df = routine_dat_use
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
    bayescoveragemodel::plot_estimates_local_all(results = rv$fit_local)
  })




  # Output: Estimates table preview
  output$estimates_table <- renderTable({
    req(rv$fit_local)
    head( rv$fit_local$posterior$temporal |>
            dplyr::rename(estimate = `50%`,
                   lower_95 =`2.5%`,,
                   upper_95 = `97.5%`) |>
            dplyr::select(year, estimate, lower_95, upper_95)
          , 10)
  })

  # Download handler for CSV
  output$download_csv <- downloadHandler(
    filename = function() {
      paste0("estimates_", input$indicator, "_", input$iso_code, "_", Sys.Date(), ".csv")
    },
    content = function(file) {
      req(rv$fit_local)
      write_csv(rv$fit_local$posterior$temporal |>
                  dplyr::rename(estimate = `50%`,
                         lower_95 =`2.5%`,,
                         upper_95 = `97.5%`) |>
                  dplyr::select(year, estimate, lower_95, upper_95), file)
    }
  )
}

# Run the app
shinyApp(ui = ui, server = server)
