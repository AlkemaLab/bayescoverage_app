
<!-- README.md is generated from README.Rmd. Please edit that file -->

# BayesCoverage App

**For information on installation, please see the “Installation” section
below.**

Repository with code and Shiny app to fit Bayesian hierarchical
transition models to health coverage indicators (e.g., ANC4,
institutional delivery) using survey and routine data.

The modeling is based on the R package `bayescoveragemodel`, see
<https://alkemalab.github.io/bayescoveragemodel/>. However, to avoid
installation issues related to C++ compilers, we added the
Bayescoveragedeploy package, see
<https://github.com/AlkemaLab/bayescoveragedeploy/>, which contains
precompiled Stan models. Through the deploy package, you can use the
Shiny app without needing to install cmdstanr etc on your machine. The
deploy package is available here:
<https://alkemalab.r-universe.dev/builds>

This work was supported, in whole or in part, by the Bill & Melinda
Gates Foundation (INV-001299).

# Installation

To avoid installation issues related to C++ compilers, we added the
Bayescoveragedeploy package, which contains precompiled Stan models.
This means you can install the package and use the Shiny app without
needing to install cmdstanr or CmdStan on your machine.

Install the following Bayescoverage-related packages from github (now
also available via R universe)
`devtools::install_github("AlkemaLab/bayescoveragemodel")`
`devtools::install_github("AlkemaLab/localhierarchy")`

Install the following Bayescoverage-related packages from R universe:

`install.packages('bayescoveragedeploy', repos = c('https://alkemalab.r-universe.dev'))`

Also install the following package from CRAN:
`install.packages(c("dplyr", "haven", "ggplot2", "shiny", "posterior", "readr", "here", "stringr", "tibble"))`

For using routine data, `brms` is used as well, install using

`install.packages("brms")`

# Data and analysis

Example survey data are included in the `data_raw` folder. Model fitting
with survey data is illustrated in `analysis/bayescoverageapp.qmd` and
`analysis/shinyapp.R`.

Routine data are not on github, store those in your local
`private/routinedata/` folder. For testing, a routine toy data set is
included in the `data_raw` folder, you need to add `iso` and
`indicator_name` to that data set to use it, see quarto and shiny app
for example use.
