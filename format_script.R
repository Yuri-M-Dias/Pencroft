
library(tidyverse)
library(parallel)

library(styler)
library(formatR)

# TODO: convert the bash file to pure R...?

current.wd = getwd()
message(sprintf("Current working dir: %s", current.wd))

kernels.data.path = "/Data/"

# TODO:Get all scripts from all of the subdirs
kernels.scripts = vector()

kernels.authors = dir(
    path = paste0(current.wd, kernels.data.path),
    include.dirs = TRUE
)
message(sprintf("Found %i authors", length(kernels.authors)))

for (author in kernels.authors) {
  author.kernels.dirs = dir(
      path = paste0(current.wd, kernels.data.path, '/', author),
      include.dirs = TRUE
  )
  message(sprintf(
    "Found %i kernels for the author %s",
    length(author.kernels.dirs),
    author
  ))
  
  for (kernel in author.kernels.dirs) {
    message(sprintf("Kernel %s", kernel))
    
    # Only one script per kernel
    kernel.script = dir(
        path = paste0(
          current.wd,
          kernels.data.path,
          '/',
          author,
          '/',
          kernel
        ),
        pattern = "\\.R$", # Ignoring Rmd files for now
        include.dirs = FALSE
    )
    message(sprintf("Script: %s", kernel.script))
    kernels.scripts = append(kernels.scripts,kernel.script)
  }
  
}

message(sprintf("Scripts: %s", kernels.scripts))
