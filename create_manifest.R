# Create manifest.json for Posit Cloud deployment
# This ensures cmdstanr is properly referenced from GitHub

cat("Checking cmdstanr installation source...\n")

# Check if cmdstanr is installed from GitHub
if (requireNamespace("cmdstanr", quietly = TRUE)) {
  pkg_desc <- packageDescription("cmdstanr")
  if (!is.null(pkg_desc$GithubRepo)) {
    cat("✓ cmdstanr is installed from GitHub\n")
  } else {
    cat("⚠ cmdstanr is NOT from GitHub. Reinstalling from GitHub...\n")
    remove.packages("cmdstanr")
    remotes::install_github("stan-dev/cmdstanr")
  }
} else {
  cat("Installing cmdstanr from GitHub...\n")
  remotes::install_github("stan-dev/cmdstanr")
}

cat("\nCreating manifest.json for Posit Cloud...\n")

# Make sure we're in the right directory (where shinyapp.R is)
setwd("analysis")

# Create the manifest
rsconnect::writeManifest()

cat("\n✓ manifest.json created in analysis/ folder!\n")
cat("\nNext steps:\n")
cat("1. Commit analysis/manifest.json to git\n")
cat("2. Push to GitHub\n")
cat("3. Deploy to Posit Cloud\n")
cat("\nNote: On Posit Cloud after deployment, you'll need to run:\n")
cat("  cmdstanr::install_cmdstan()\n")
