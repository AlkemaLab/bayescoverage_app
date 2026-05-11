
<!-- README.md is generated from README.Rmd. Please edit that file -->

# BayesCoverage App

Repository with code and Shiny app to fit Bayesian hierarchical
transition models to health coverage indicators (e.g., ANC4,
institutional delivery) using survey and routine data.

The app uses the R package `bayescoveragemodel`, see
<https://alkemalab.github.io/bayescoveragemodel/>.

This work was supported, in whole or in part, by the Bill & Melinda
Gates Foundation (INV-001299).

# Installation

Dependencies

- `cmdstanr`: Instructions for installing `cmdstanr` are available in
  their [Getting
  started](https://mc-stan.org/cmdstanr/articles/cmdstanr.html) guide.
  If helpful, see this g-doc
  <https://docs.google.com/document/d/1veMoHhijzYUzPA0LuZcw1T3B1ewjvVQhlsZgSNQ5GjQ/edit?usp=sharing>

- R package `localhierarchy`, available at
  [github.com/AlkemaLab/localhierarchy](https://github.com/AlkemaLab/localhierarchy).
  You can install it using

`remotes::install_github("AlkemaLab/localhierarchy")`

- R package `bayescoveragemodel`, install using

`remotes::install_github("AlkemaLab/bayescoveragemodel")`

- For using routine data, `brms` is used as well, install using

`install.packages("brms")`
