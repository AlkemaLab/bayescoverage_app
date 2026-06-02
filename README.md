
<!-- README.md is generated from README.Rmd. Please edit that file -->

# Update June 1, 2026

App is working with deploy package hoorah! But version update 0.1.01 on
R universe is pending. This page will show you if windows build was
successful <https://alkemalab.r-universe.dev/builds>

# BayesCoverage App

Repository with code and Shiny app to fit Bayesian hierarchical
transition models to health coverage indicators (e.g., ANC4,
institutional delivery) using survey and routine data.

The modeling is based on the R package `bayescoveragemodel`, see
<https://alkemalab.github.io/bayescoveragemodel/>. However, to avoid
installation issues related to C++ compilers, we added the
Bayescoveragedeploy package, see
<https://github.com/AlkemaLab/bayescoveragedeploy/>, which contains
precompiled Stan models. Through the deploy package, you can use the
Shiny app without needing to install cmdstanr etc on your machine.

This work was supported, in whole or in part, by the Bill & Melinda
Gates Foundation (INV-001299).

# Installation

To avoid installation issues related to C++ compilers, we added the
Bayescoveragedeploy package, which contains precompiled Stan models.
This means you can install the package and use the Shiny app without
needing to install cmdstanr or CmdStan on your machine.

Install the following Bayescoverage-related packages from github
(releases via R universe are pending)
`devtools::install_github("AlkemaLab/bayescoveragemodel")`
`devtools::install_github("AlkemaLab/localhierarchy")`

Install the following Bayescoverage-related packages from R universe:

`install.packages('bayescoveragedeploy', repos = c('https://alkemalab.r-universe.dev')`

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
