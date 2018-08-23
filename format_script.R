
library(tidyverse)
library(parallel)


# TODO: convert the bash file to pure R...?

current.wd = getwd()
message(sprintf("Current working dir: %s", current.wd))

kernels.data.path = "/Data/"

# TODO:Get all scripts from all of the subdirs
kernels.paths = vector()

kernels.authors = dir(
    path = paste0(current.wd, kernels.data.path),
    include.dirs = TRUE
)
message(sprintf("Found %i authors", length(kernels.authors)))

for (author in kernels.authors) {
  author.kernels.dirs = dir(
      path = paste0(current.wd, kernels.data.path, author),
      include.dirs = TRUE
  )
  message(sprintf(
    "Found %i kernels for the author %s",
    length(author.kernels.dirs),
    author
  ))
  
  for (kernel in author.kernels.dirs) {
    message(sprintf("Kernel %s", kernel))
    
    kernel.path = paste0(current.wd, kernels.data.path, author, '/', kernel)
    # Only one script per kernel
    kernel.script = dir(
        path = kernel.path,
        pattern = "\\.R$", # Ignoring Rmd files for now
        include.dirs = FALSE
    )
    
    if (!is_empty(kernel.script)){
      message(sprintf("Script: %s", kernel.script))
      kernel.path.complete = paste0(kernel.path, '/', kernel.script)
      kernels.paths = append(kernels.paths, kernel.path.complete)
    }
  }
  
}

library(styler)
library(formatR)

for (kernel in kernels.paths) {
  message(sprintf("%s", kernel))
  
  # Creates backups...
  kernel.styler = gsub('\\.R', '-styler\\.R', kernel)
  kernel.formatr = gsub('\\.R', '-formatr\\.R', kernel)
  file.copy(from = kernel, to = kernel.styler)
  file.copy(from = kernel, to = kernel.formatr)
  
  # TODO: styles?!
  styler::style_file(
    kernel.styler, style = tidyverse_style, strict = TRUE
  )
  formatR::tidy_file(file = kernel.formatr)
}
