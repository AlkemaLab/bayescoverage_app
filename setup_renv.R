# Setup script for renv

# Install renv if needed
if (!require("renv", quietly = TRUE)) {
  install.packages("renv")
}

# Initialize renv (bare mode to not install all packages yet)
cat("Initializing renv...\n")
renv::init(bare = TRUE)

cat("renv initialized successfully!\n")

# Install cmdstanr first (required by brms and bayescoveragemodel)
cat("\nInstalling cmdstanr...\n")
if (!requireNamespace("cmdstanr", quietly = TRUE)) {
  cat("Installing cmdstanr from R-universe...\n")
  tryCatch({
    install.packages("cmdstanr", repos = c("https://stan-dev.r-universe.dev", getOption("repos")))

    # Install CmdStan
    cat("Installing CmdStan...\n")
    cmdstanr::install_cmdstan()
    cat("cmdstanr and CmdStan installed successfully!\n")
  }, error = function(e) {
    cat(paste0("Warning: Could not install cmdstanr. Error: ", e$message, "\n"))
    cat("Please install manually using:\n")
    cat("install.packages('cmdstanr', repos = c('https://stan-dev.r-universe.dev', getOption('repos')))\n")
    cat("cmdstanr::install_cmdstan()\n")
  })
} else {
  cat("cmdstanr is already installed.\n")
}

# Install required CRAN packages for the shiny app
cat("\nInstalling required CRAN packages...\n")
cran_packages <- c(
  "shiny",
  "tidyverse",
  "ggplot2",
  "haven",
  "brms",
  "here",
  "rsconnect",
  "remotes"
)

for (pkg in cran_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    cat(paste0("Installing ", pkg, "...\n"))
    tryCatch({
      renv::install(pkg)
    }, error = function(e) {
      cat(paste0("Warning: Could not install ", pkg, ". Error: ", e$message, "\n"))
    })
  } else {
    cat(paste0(pkg, " is already installed.\n"))
  }
}

# Install GitHub packages
cat("\nInstalling GitHub packages...\n")

# Install localhierarchy from GitHub
if (!requireNamespace("localhierarchy", quietly = TRUE)) {
  cat("Installing localhierarchy from GitHub...\n")
  tryCatch({
    renv::install("AlkemaLab/localhierarchy")
  }, error = function(e) {
    cat(paste0("Warning: Could not install localhierarchy. Error: ", e$message, "\n"))
  })
} else {
  cat("localhierarchy is already installed.\n")
}

# Install bayescoveragemodel from GitHub
if (!requireNamespace("bayescoveragemodel", quietly = TRUE)) {
  cat("Installing bayescoveragemodel from GitHub...\n")
  tryCatch({
    renv::install("AlkemaLab/bayescoveragemodel")
  }, error = function(e) {
    cat(paste0("Warning: Could not install bayescoveragemodel. Error: ", e$message, "\n"))
  })
} else {
  cat("bayescoveragemodel is already installed.\n")
}

# Snapshot the environment to capture all dependencies
cat("\nCreating renv snapshot...\n")
renv::snapshot(prompt = FALSE)

cat("\n✓ renv setup complete!\n")
cat("All package dependencies have been recorded in renv.lock\n")
cat("\nIMPORTANT: cmdstanr dependency\n")
cat("This app requires cmdstanr. On Posit Cloud, you'll need to:\n")
cat("1. Install cmdstanr: install.packages('cmdstanr', repos = c('https://stan-dev.r-universe.dev', getOption('repos')))\n")
cat("2. Install CmdStan: cmdstanr::install_cmdstan()\n")
cat("\nNext steps for Posit Cloud deployment:\n")
cat("1. Commit the renv.lock file to your git repository\n")
cat("2. Push to GitHub/GitLab\n")
cat("3. Deploy to Posit Cloud - it will automatically restore packages from renv.lock\n")
cat("4. After deployment, install cmdstanr following the instructions above\n")
