#!/usr/bin/env Rscript

# TODO: deal with duplicated names

packages <- c("optparse",
              "Biostrings",
              "data.table",
              "xtable",
              "xml2",
              "gtools",
              "envDocument")
if (length(setdiff(packages, rownames(installed.packages()))) > 0) {
  install.packages(setdiff(packages, rownames(installed.packages())))  
}

suppressPackageStartupMessages(library("optparse"))
suppressPackageStartupMessages(library("Biostrings"))
suppressPackageStartupMessages(library("data.table"))
library("xtable")
library("xml2")
library("gtools")
library("envDocument")

description <- "
Makes an HTML table with colored positions that are identical to the type
and class consensuses without positions that are the same in both consensus.

Option --sortByTypeCons creates table sorted by similarities with type consensus.

If optional parameter --baseSubs is used then replacement table is applied
to substitute position (usually contain N) to another one or multiple (A/T/G).

Input:  FASTA alignment, were first seq is type consensus, and secont seq
        is class consensus
Output: HTML table"

option_list <- list(
  make_option(c("-i", "--input"), action="store",
              help="Input FASTA alignment"),
  make_option(c("-o", "--output"), action="store", default="out.html",
             help="Output file name [default %default]"),
  make_option(c("-b", "--baseSubs"), action="store",
              help="Tab delimited file for substitutions in bases
                Format: FASTA_name base_position base_value"),
  make_option(c("-s", "--sortByTypeCons"), action="store_true", default=F,
              help="Sort output by similarities with type
                consensus [default %default]"),
  make_option(c("-t", "--thrd"), action="store", type="integer", default=0,
              help="Threshold for number of similarities with type consensus.
                This implies sorting by names within each group by threshold.")
)

opt_parser <- OptionParser(option_list=option_list, description=description)
opt <- parse_args(opt_parser)

if(is.null(opt$i)){
  print_help(opt_parser)
  stop("\ninput FASTA alignment is required\n")
}

inputFasta <- readDNAStringSet(opt$i)

# fasta to dataframe
seq_name = names(inputFasta)
sequence = paste(inputFasta)
df <- data.frame(seq_name, sequence)

# transpose and assign names
df <- setnames(setDT(df)[, transpose(.SD[, -1])], seq_name)

# split every character of string in a row into columns
df <- setDT(df)[, lapply(.SD, function(x) unlist(tstrsplit(x, "", fixed = T)))][]

if(!is.null(opt$b)){
  baseSubs <- read.delim(opt$b, header = F, stringsAsFactors = T, strip.white = T)
  colnames(baseSubs) <- c("subsName", "subsPosition", "subsValue")
  # replace values in table df using reference in table baseSubs
  len <- seq_len(nrow(baseSubs))
  for(i in len){
    bsname <- as.character(baseSubs$subsName[i])
    bspos  <- as.integer(baseSubs$subsPosition[i])
    bsval  <- as.character(baseSubs$subsValue[i])
    # assign value by reference
    set(df, i = bspos, j = bsname, value = bsval)
  }
}

# add column with index as row number
df[, id := .I]
setkey(df, id)

# remove rows if first two columns have identical values
df <- setDT(df)[, .SD[!apply(.SD[, c(1:2)], 1, function(x) uniqueN(x)==1)]]

# transpose all and set id as column names
df <- setnames(
              setDT(df)[,
                        data.table(t(.SD), keep.rownames = T),
                        .SDcols = -"id"
                       ],
                       df[, c("rn", id)]
              )[]

# type consensus
typeCons  <- df[1][, -1]
# class consensus
classCons <- df[2][, -1]

# for each line below the second counts the number of
# similarities for each position with the type consensus
simtcv <- vector("integer")
simccv <- vector("integer")
len <- seq_len(nrow(df[-c(1:2), -1]))
for(i in len){
  simtcv[i] <- sum(
    diag(
      apply(
        df[-c(1:2), -1][i], 2, function(y) apply(
          typeCons, 1, function(x) grepl(y, x)
        )
      )
    )
  )
  simccv[i] <- sum(
    diag(
      apply(
        df[-c(1:2), -1][i], 2, function(y) apply(
          classCons, 1, function(x) grepl(y, x)
        )
      )
    )
  )
}
# add vector with values to table
# this vector two values short than number of rows
# therefore first two rows will have N/A
df[-c(1:2), simtc:=simtcv]
df[-c(1:2), simcc:=simccv]

# sorting output by similarities with type consensus
if(isTRUE(opt$s)){
  # add key
  setkey(df, simtc)
  # reorder in descending order
  setorder(df, -simtc)
}

# sorting by names within each group by threshold
if(is.numeric(opt$t) & (opt$t > 0) & isTRUE(opt$s)){
  # make new column with names without dots
  df <- df[, rn2:=gsub("[.]", "", rn)]
  # store first two rows
  typeAndClassCons <- df[c(1:2), ]
  # remove first two rows from table
  df <- df[-c(1:2), ]
  # sort by new names (excluding first two rows)
  df <- df[gtools::mixedorder(as.character(df$rn2))]
  # add column with index as row number
  df[, id2:=.I]
  # reorder table in two groups sorted alphabetically based on similarities
  # treshold and merge groups together
  df <- rbindlist(
    list(
      typeAndClassCons,
      setorder(df[, .SD[simtc > opt$t]], id2),
      setorder(df[, .SD[simtc <= opt$t]], id2)
    ),
    use.names = T,
    fill = T
  )
  # remove temporary columns
  df <- df[, !c("rn2", "id2")]
}

# store FASTA names
n <- df$rn
# convert data table to data frame
df <- as.data.frame(df[, !c("rn")])
# assing FASTA names to row names
rownames(df) <- n

# create output file
outf <- file(opt$o, "wa")
# linking files
writeLines("<link href=\"style.css\" rel=\"stylesheet\" media=\"all\">", outf)
writeLines("<script src=\"jquery.min.js\"></script>", outf)
writeLines("<script src=\"script.js\"></script>", outf)
# create HTML table
tbl <- print.xtable(xtable(df),
                    html.table.attributes = NULL,
                    type = "html",
                    comment = F,
                    print.results = F,
                    include.colnames = T)
tbl.xml <- read_xml(tbl)
allNodes <- xml_find_all(tbl.xml, "//td")
invisible(lapply(allNodes, function(x) {
  xml_set_text(x, xml_text(x, trim = T))
}))
allNodes <- xml_find_all(tbl.xml, "//th")
invisible(lapply(allNodes, function(x) {
  xml_set_text(x, xml_text(x, trim = T))
}))
write_xml(tbl.xml, outf, options = c("no_declaration"))
close(outf)

# Code below modified version of the BootstrapDatepicker.R from Shiny
# https://github.com/rstudio/shiny/tree/master/tools

# This script copies resources from Bootstrap Datepicker to shiny's inst
# directory. The bootstrap-datepicker/ project directory should be on the same
# level as the shiny/ project directory.

# It is necessary to run Grunt after running this script: This copies the
# un-minified JS file over, and running Grunt minifies it and inlines the locale
# files into the minified JS.

# This script can be sourced from RStudio, or run with Rscript.

# Returns the file currently being sourced or run with Rscript
thisFile <- function() {
  cmdArgs <- commandArgs(trailingOnly = FALSE)
  needle <- "--file="
  match <- grep(needle, cmdArgs)
  if (length(match) > 0) {
    # Rscript
    return(normalizePath(sub(needle, "", cmdArgs[match])))
  } else {
    # 'source'd via R console
    return(normalizePath(sys.frames()[[1]]$ofile))
  }
}

srcdir <- normalizePath(file.path(dirname(thisFile())))
destdir <- normalizePath(file.path(dirname(".")))

invisible(
  file.copy(
    file.path(srcdir, "script.js"),
    file.path(destdir, "script.js"),
    overwrite = TRUE
  )
)

invisible(
  file.copy(
    file.path(srcdir, "jquery.min.js"),
    file.path(destdir, "jquery.min.js"),
    overwrite = TRUE
  )
)

invisible(
  file.copy(
    file.path(srcdir, "style.css"),
    file.path(destdir, "style.css"),
    overwrite = TRUE
  )
)
