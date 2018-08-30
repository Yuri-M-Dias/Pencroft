
library(tidyverse)
library(parallel)

# TODO: convert the bash file to pure R...?

# Assuming root folder
current.wd = getwd()
message(sprintf("Current working dir: %s", current.wd))

kernels.data.path = "/Data/"

# TODO:Get all scripts from all of the subdirs
kernels.paths = vector()

kernels.authors = dir(
    path = paste0(current.wd, kernels.data.path),
    include.dirs = TRUE
)
#message(sprintf("Found %i authors", length(kernels.authors)))

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
    #message(sprintf("Kernel %s", kernel))

    kernel.path = paste0(current.wd, kernels.data.path, author, '/', kernel)
    # Only one script per kernel
    kernel.script = dir(
        path = kernel.path,
        pattern = "\\.R[md]*",
        include.dirs = FALSE
    )

    if (!is_empty(kernel.script)){
      kernel.path.complete = paste0(kernel.path, '/', kernel.script)
      #message(sprintf("Script: %s", kernel.path.complete))
      kernels.paths = append(kernels.paths, kernel.path.complete)
    }
  }

}

library(styler)
library(formatR)

for (kernel in kernels.paths) {
  message(sprintf("Formatting %s", kernel))

  # Creates backups, since both tools replace the original file
  kernel.styler = gsub('\\.R([md]*)', '-styler\\.R\\1', kernel)
  kernel.formatr = gsub('\\.R([md]*)', '-formatr\\.R\\1', kernel)
  message(sprintf("%s", kernel.styler))
  file.copy(from = kernel, to = kernel.styler)
  file.copy(from = kernel, to = kernel.formatr)

  # TODO: styles?!
  styler::style_file(
    kernel.styler,
    style = tidyverse_style,
    strict = TRUE
  )

  #TODO: check if Rmd!

  formatR::tidy_file(
    file = kernel.formatr
  )

}

