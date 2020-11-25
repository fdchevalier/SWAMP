#!/usr/bin/env Rscript
# Title: quant_mvt.R
# Version: 0.1
# Author: Frédéric CHEVALIER <fcheval@txbiomed.org>
# Created in: 2020-10-29
# Modified in: 2020-11-24 
# Licence: GPL v3



#==========#
# Comments #
#==========#

aim <- "Analyze table of movement index (absolute error) between well images and output table and graphs."



#==========#
# Versions #
#==========#

# v0.1 - 2020-11-24: add prefix and layout options / improve bad well detection / use properly well numbering / correct typo
# v0.0 - 2020-10-29: creation



#==========#
# Packages #
#==========#

suppressMessages({
    library("optparse")
    library("ggplot2")
    library("platetools")
    library("magrittr")
})



#===========#
# Variables #
#===========#

# Options
option_list <- list(
    make_option(c("-f", "--file"), type="character", default=NULL,
                  help="dataset file", metavar="character"),
    make_option(c("-l", "--layout"), type="character", default="out.txt",
                  help="plate layout file", metavar="character"),
    make_option(c("-p", "--prefix"), type="character", default=".",
                  help="prefix of the folder where data is available and results will be stored", metavar="character")
)

# Parse options
opt_parser <- OptionParser(option_list = option_list)
opt <- parse_args(opt_parser)

# Check mandatory arguments
if (is.null(opt$file)){
  print_help(opt_parser)
  stop("At least one argument must be supplied (input file).", call.=FALSE)
}

filename <- basename(opt$file) %>% tools::file_path_sans_ext()

# Graphic options
graph_fd <- "graphs/"
#theme_set(theme_classic())



#=================#
# Data processing #
#=================#

# Load data
mytable  <- read.delim(opt$file)
mylayout <- read.delim(opt$layout)

# Check layout
if ( ! all(mylayout[,1] %in% num_to_well(1:96)) ) { stop("Wells are not well formatted.") }

# Reorder rows
mytable <- mytable[match(mylayout[, 1], mytable[, 1]), ]

# Identify blank wells
myblank <- mylayout[,2] == "blank"


#----------------------------#
# Identify problematic wells #
#----------------------------#

# Compute normalized distance from the mean
mysd <- apply(mytable[myblank,2:ncol(mytable)], 1, function(x) ( (x - mean(x)) / sqrt(mean(x))) )
mysd[ ! is.finite(mysd) ] <- 0

# Filter on max distance to the mean and invert coefficient of variation
bad_wells <- apply(mysd, 1, max) >= 10 | apply(mysd, 1, sd) >= 4 
bad_wells_tmp <- ((apply(mysd, 1, function(x) mean(x) / sd(x)) ) %>% abs() %>% round() ) >= 4
bad_wells_tmp[ is.na(bad_wells_tmp) ]  <- FALSE
bad_wells <- bad_wells | bad_wells_tmp

# Keep only good wells
bs <- apply(mytable[, 2:ncol(mytable)][, ! bad_wells], 1, function(x) mean(x))
names(bs) <- mytable[,1]


#-------------#
# Final table #
#-------------#

cs <- merge(mylayout, as.data.frame(bs), by.x=1, by.y="row.names")

cs2 <- cs[ ! myblank, ]

# Write table with average values
write.table(cs2, paste0(opt$prefix, "/", filename, "_mean.tsv"), row.names = FALSE, sep = "\t")



#=========#
# Figures #
#=========#

if( ! dir.exists(graph_fd)) { dir.create(graph_fd, recursive = TRUE) }

#-------------------------#
# Global group comparison #
#-------------------------#

png(paste0(graph_fd, filename, "_boxplot.png"))
boxplot(cs[,3] ~ cs[,2])
dev.off()


#--------------------------#
# Average movement by well #
#--------------------------#

png(paste0(graph_fd, filename, "_mean.png"))
raw_map(data = cs[,3],
        well = cs[,1],
        plate = 96) +
    scale_fill_gradient(low = "white", high = "black")
dev.off()

pdf(paste0(graph_fd, filename, "_mean_final.pdf"))
cs.tmp <- cs
myclr  <- rep(NA, nrow(cs))
myfill <- rep(NA, nrow(cs))
myclr[ cs[,2] == "blank" ]  <- "grey20"
myfill[ cs[,2] == "blank" ] <- "white"
raw_map(data = cs.tmp[,3],
        well = cs.tmp[,1],
        plate = 96) +
    geom_point(fill = myfill, colour = myclr, size = ((sqrt(10^2/2) *10) %>% floor(.) ) / 10, shape = 4) +
    scale_fill_gradient(low = "white", high = "black") +
    theme(panel.grid.minor = element_blank())
dev.off()


#--------------------------#
# Frame differences output #
#--------------------------#

graph_fd_d <- paste0(graph_fd, "discarded images/")
graph_fd_r <- paste0(graph_fd, "retained images/")

if( ! dir.exists(graph_fd_d)) { dir.create(graph_fd_d, recursive = TRUE) }
if( ! dir.exists(graph_fd_r)) { dir.create(graph_fd_r, recursive = TRUE) }

# Output graph for each column of the input table
for (i in 2:(ncol(mytable)-1)) {

    if (bad_wells[i-1]) {
    png(paste0(graph_fd_d, filename, "_", colnames(mytable)[i], ".png"))
        p <- raw_map(data = mytable[, i],
                well = mytable[, 1],
                plate = 96) +
            scale_fill_gradient(low = "white", high = "black", limits = range(mytable[, 2:(ncol(mytable)-1)]))
    } else {
        png(paste0(graph_fd_r, filename, "_", colnames(mytable)[i], ".png"))
        p <- raw_map(data = mytable[, i],
                well = mytable[, 1],
                plate = 96) +
            scale_fill_gradient(low = "white", high = "black", limits = range(mytable[, 2:(ncol(mytable)-1)]))
    }

    print(p)
    dev.off()
}
