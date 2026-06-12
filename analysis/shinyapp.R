# Shiny App for Bayesian Coverage Analysis
# Takes in country data and outputs estimates in a CSV

# # Installation instructions are in readme, copied here
# devtools::install_github("AlkemaLab/bayescoveragemodel")
# devtools::install_github("AlkemaLab/localhierarchy")
# install.packages('bayescoveragedeploy',
#                  repos = c('https://alkemalab.r-universe.dev'))
# install.packages(c("dplyr", "haven", "ggplot2", "shiny",  "readr", "here", "stringr",
#    "tibble", "posterior"))
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
      # Estimation mode selection
      radioButtons("estimation_mode", "Estimation Mode:",
                   choices = c("National" = "national",
                               "Subnational" = "subnational"),
                   selected = "national"),

      hr(),

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

      # Indicator selection (dynamic based on mode)
      uiOutput("indicator_ui"),

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
        uiOutput("routine_help_text")
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

      # Plot output (dynamic based on mode)
      uiOutput("plot_output_ui"),

      # Estimates table preview (only for national mode)
      conditionalPanel(
        condition = "input.estimation_mode == 'national'",
        h4(textOutput("estimates_table_title")),
        tableOutput("estimates_table")
      )
    )
  )
)

# Server
server <- function(input, output, session) {

  # Reactive values to store results
  rv <- reactiveValues(
    fit_local = NULL,
    model_complete = FALSE,
    single_plot = NULL,       # For national mode
    comparison_plot = NULL,   # For subnational comparison plot
    admin1_regions = NULL     # Store admin1 regions for subnational mode
  )

  # Dynamic UI: Indicator selection based on mode
  output$indicator_ui <- renderUI({
    if (input$estimation_mode == "subnational") {
      choices <- c("cci", "anc4")
      selected <- "anc4"
    } else {
      choices <- indicator_all
      selected <- "anc4"
    }

    selectInput("indicator", "Select Indicator:",
                choices = choices,
                selected = selected)
  })

  # Dynamic UI: Routine data help text based on mode
  output$routine_help_text <- renderUI({
    if (input$estimation_mode == "subnational") {
      helpText("Expected format for SUBNATIONAL: admin1, year, routine_value, countdownmean, indicator_name. NOTE: Do NOT include 'iso' column.")
    } else {
      helpText("Expected format for NATIONAL: iso, year, routine_value, countdownmean, indicator_name.")
    }
  })

  # Dynamic UI: Estimates table title (national mode only)
  output$estimates_table_title <- renderText({
    "Estimates Preview:"
  })

  # Load data based on source selection
  data_raw <- reactive({
    # Determine which file to load based on mode
    default_file <- if (input$estimation_mode == "subnational") {
      "ICEH_gregion_20260611.dta"
    } else {
      "ICEH_all.long_20260603.dta"
    }

    if (input$data_source == "existing") {
      file_path <- here::here(data_folder, default_file)

      if (!file.exists(file_path)) {
        stop(paste0(
          "Data file not found: ", default_file, ". ",
          "Please upload a file or contact administrator."
        ))
      }

      dat <- haven::read_dta(file_path) |>
        dplyr::rename(r = r_raw, se = se_raw)

      # For subnational, also rename level to admin1
      if (input$estimation_mode == "subnational") {
        dat <- dat |> dplyr::rename(admin1 = level)
      }

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

      # For subnational mode, verify admin1 column exists
      if (input$estimation_mode == "subnational" && !"admin1" %in% names(dat)) {
        stop("Subnational mode requires 'admin1' column in uploaded data")
      }

      return(dat)
    }
  })

  # Start over when button clicked
  observeEvent(input$start_over, {
    rv$fit_local <- NULL
    rv$model_complete <- FALSE
    rv$single_plot <- NULL
    rv$comparison_plot <- NULL
    rv$admin1_regions <- NULL
    showNotification("Results cleared. Ready to run a new model.", type = "message", duration = 3)
  })

  # Clear results when mode changes
  observeEvent(input$estimation_mode, {
    if (!is.null(rv$fit_local)) {
      rv$fit_local <- NULL
      rv$model_complete <- FALSE
      rv$single_plot <- NULL
      rv$comparison_plot <- NULL
      rv$admin1_regions <- NULL
      showNotification(
        paste("Switched to",
              ifelse(input$estimation_mode == "subnational", "subnational", "national"),
              "mode. Previous results cleared."),
        type = "message",
        duration = 3
      )
    }
  }, ignoreInit = TRUE)

  # Run model when button clicked
  observeEvent(input$run_model, {
    req(input$iso_code)

    rv$model_complete <- FALSE
    rv$fit_local <- NULL
    rv$admin1_regions <- NULL

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
          dat = dat0 |>
            dplyr::filter(iso %in% iso_select),
          regions_dat = bayescoveragemodel::regions_all,
          indicator = indicator_select, verbose = FALSE)


        # Check if ISO exists in data
        if (!iso_select %in% unique(dat$iso)) {
          stop(paste("ISO code", iso_select, "not found in data. Available codes:",
                     paste(head(unique(dat$iso), 20), collapse = ", ")))
        }

        # Validate data is not empty
        if (nrow(dat) == 0) {
          stop(paste(
            "No data found for ISO code", iso_select,
            "in", input$estimation_mode, "mode."
          ))
        }

        # For subnational mode, verify indicator is supported and check admin1 regions
        if (input$estimation_mode == "subnational") {
          supported_indicators <- c("cci", "anc4")

          if (!indicator_select %in% supported_indicators) {
            stop(paste0(
              "Indicator '", indicator_select, "' is not supported in subnational mode. ",
              "Supported indicators: ", paste(supported_indicators, collapse = ", ")
            ))
          }

          # Verify admin1 regions exist and store them
          admin1s <- sort(unique(dat$admin1))
          if (length(admin1s) == 0) {
            stop("No admin1 regions found in data for selected country")
          }

          # Store admin1 regions for dropdown
          rv$admin1_regions <- admin1s
        }

        incProgress(0.4, detail = paste0(
          "Fitting ",
          ifelse(input$estimation_mode == "subnational", "subnational", "national"),
          " model (this may take a few minutes)..."
        ))

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

            # Mode-specific validation
            if (input$estimation_mode == "subnational") {
              required_cols <- c("admin1", "year", "routine_value", "countdownmean", "indicator_name")

              # Check for admin1 column
              if (!"admin1" %in% names(routine_dat_raw)) {
                stop("Subnational routine data must include 'admin1' column")
              }

              # Check that iso column is NOT present
              if ("iso" %in% names(routine_dat_raw)) {
                stop("Subnational routine data should NOT include 'iso' column. Please remove it.")
              }

              # Validate columns
              missing_cols <- setdiff(required_cols, names(routine_dat_raw))
              if (length(missing_cols) > 0) {
                stop(paste("Uploaded routine data is missing required columns:",
                          paste(missing_cols, collapse = ", ")))
              }

              # Filter by indicator only (no iso filtering)
              routine_dat_use <- routine_dat_raw |>
                dplyr::filter(indicator_name == indicator_select)

            } else {
              # National mode validation
              required_cols <- c("iso", "year", "routine_value", "countdownmean", "indicator_name")

              if (!"iso" %in% names(routine_dat_raw)) {
                stop("National routine data must include 'iso' column")
              }

              # Validate columns
              missing_cols <- setdiff(required_cols, names(routine_dat_raw))
              if (length(missing_cols) > 0) {
                stop(paste("Uploaded routine data is missing required columns:",
                          paste(missing_cols, collapse = ", ")))
              }

              routine_dat_use <- routine_dat_raw |>
                dplyr::filter(iso == iso_select, indicator_name == indicator_select)
            }

          } else {
            # Use existing (dummy) routine data
            routine_dat_raw <- readr::read_csv(here::here("data_raw/routine_toydata.csv"),
                                        show_col_types = FALSE)

            if (input$estimation_mode == "subnational") {
              # For subnational, need to get admin1 regions from survey data
              admin1s <- sort(unique(dat$admin1))

              # Create routine data for first region only (as in example)
              routine_dat_use <- routine_dat_raw |>
                dplyr::mutate(admin1 = admin1s[1],
                             indicator_name = indicator_select) |>
                dplyr::select(-iso)  # Remove iso column
            } else {
              # For national, add iso and indicator_name
              routine_dat_use <- routine_dat_raw |>
                dplyr::mutate(iso = iso_select,
                             indicator_name = indicator_select)
            }
          }
        }


        if (input$estimation_mode == "subnational") {
          fit_local <- fit_local_model(
            survey_df = dat |> dplyr::filter(iso %in% iso_select),
            subnational = TRUE,
            indicator = indicator_select,
            iso_select = iso_select,
            routine_df = routine_dat_use,
            # these sampling settings will be the new defaults in updated deploy package
            iter_sampling = 300,
            iter_warmup = 150,
            adapt_delta = 0.95,
            max_treedepth = 14
          )
        } else {
          fit_local <- fit_local_model(
            survey_df = dat |> dplyr::filter(iso %in% iso_select),
            iso_select = iso_select,
            routine_df = routine_dat_use,
            # these sampling settings will be the new defaults in updated deploy package
            iter_sampling = 300,
            iter_warmup = 150,
            adapt_delta = 0.95,
            max_treedepth = 14
          )
        }


        incProgress(0.9, detail = "Generating plots...")

        rv$fit_local <- fit_local

        if (input$estimation_mode == "subnational") {
          # For subnational mode, only generate comparison plot
          # Regional plots will be generated on-demand when selected
          rv$comparison_plot <- bayescoveragemodel::plot_subnational_comparison(
            results = fit_local,
            model_names = "Bayesian model estimates",
            year_select = 2025
          )
          rv$single_plot <- NULL
        } else {
          # For national mode, generate the single plot
          plot_list <- bayescoveragemodel::plot_estimates_local_all(results = fit_local)
          rv$single_plot <- plot_list[[1]]
          rv$comparison_plot <- NULL
        }

        incProgress(1.0, detail = "Complete!")
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
      paste(
        ifelse(input$estimation_mode == "subnational", "Subnational", "National"),
        "mode: Ready. Select options and click 'Run Model' to start."
      )
    } else {
      paste(
        ifelse(input$estimation_mode == "subnational", "Subnational", "National"),
        "mode: Model fitting complete for", toupper(input$iso_code), "-", input$indicator
      )
    }
  })

  # Output: Dynamic plot UI based on mode
  output$plot_output_ui <- renderUI({
    req(rv$fit_local)

    if (input$estimation_mode == "subnational") {
      # For subnational, wait for comparison plot and admin1 regions to be ready
      if (is.null(rv$comparison_plot) || is.null(rv$admin1_regions)) {
        return(h4("Generating plots..."))
      }

      tagList(
        h4("Subnational Comparison (2025):"),
        plotOutput("comparison_plot", height = "600px"),
        hr(),
        selectInput("region_select",
                   "Select a region to view detailed estimates:",
                   choices = c("Select a region..." = "", rv$admin1_regions),
                   selected = ""),
        plotOutput("selected_region_plot", height = "500px")
      )
    } else {
      plotOutput("estimate_plot", height = "600px")
    }
  })

  # Output: National plot
  output$estimate_plot <- renderPlot({
    req(rv$fit_local)
    req(input$estimation_mode == "national")
    req(rv$single_plot)
    rv$single_plot
  })

  # Output: Subnational comparison plot
  output$comparison_plot <- renderPlot({
    req(rv$fit_local)
    req(input$estimation_mode == "subnational")
    req(rv$comparison_plot)
    rv$comparison_plot
  })

  # Output: Selected region plot (generated on-demand)
  output$selected_region_plot <- renderPlot({
    req(rv$fit_local)
    req(input$estimation_mode == "subnational")
    req(input$region_select)
    req(input$region_select != "")

    # Generate plot for the selected region on-demand
    plot_list <- bayescoveragemodel::plot_estimates_local_all(
      results = rv$fit_local,
      region_codes = input$region_select,
      save_plots = FALSE
    )

    # Return the first (and only) plot in the list
    plot_list[[1]]
  })




  # Output: Estimates table preview
  output$estimates_table <- renderTable({
    req(rv$fit_local)

    if (input$estimation_mode == "subnational") {
      # Show all regions, limit to first 10 rows
      rv$fit_local$posteriors$temporal |>
        dplyr::rename(estimate = `50%`,
                     lower_95 = `2.5%`,
                     upper_95 = `97.5%`) |>
        dplyr::select(iso, admin1, year, estimate, lower_95, upper_95) |>
        head(10)
    } else {
      rv$fit_local$posterior$temporal |>
        dplyr::rename(estimate = `50%`,
                     lower_95 = `2.5%`,
                     upper_95 = `97.5%`) |>
        dplyr::select(year, estimate, lower_95, upper_95)
    }
  })

  # Download handler for CSV
  output$download_csv <- downloadHandler(
    filename = function() {
      mode_suffix <- if (input$estimation_mode == "subnational") "_subnational" else "_national"
      paste0("estimates_", input$indicator, "_", input$iso_code, mode_suffix, "_", Sys.Date(), ".csv")
    },
    content = function(file) {
      req(rv$fit_local)

      if (input$estimation_mode == "subnational") {
        # Access posteriors (plural) and include admin1 column
        estimates_df <- rv$fit_local$posteriors$temporal |>
          dplyr::rename(estimate = `50%`,
                       lower_95 = `2.5%`,
                       upper_95 = `97.5%`) |>
          dplyr::select(iso, admin1, year, estimate, lower_95, upper_95)
      } else {
        # Access posterior (singular) - no admin1 column
        estimates_df <- rv$fit_local$posterior$temporal |>
          dplyr::rename(estimate = `50%`,
                       lower_95 = `2.5%`,
                       upper_95 = `97.5%`) |>
          dplyr::select(year, estimate, lower_95, upper_95)
      }

      readr::write_csv(estimates_df, file)
    }
  )
}

# Run the app
shinyApp(ui = ui, server = server)
