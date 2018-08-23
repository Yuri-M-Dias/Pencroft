#!/usr/bin/env bash

# Simply installs formatR and StyleR from github

Rscript -e 'devtools::install_github(c("yihui/formatR", "r-lib/styler"))'
