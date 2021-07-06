#!/usr/bin/env Rscript
# Title: quant_mvt.R
# Version: 0.4
# Author: Frédéric CHEVALIER <fcheval@txbiomed.org>
# Created in: 2020-10-29
# Modified in: 2021-04-15
# Licence: GPL v3



#==========#
# Comments #
#==========#

aim <- "Analyze table of movement index (absolute error) between well images and output table and graphs."



#==========#
# Versions #
#==========#

# v0.4 - 2021-04-15: add skip bad well filtering option
# v0.3 - 2021-03-28: escape % sign in filename / TODO: add standard error column in output file
# v0.2 - 2021-03-13: update output file locations and types / add quality check folder option / create report / correct bug in output frame differences
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
                  help="prefix of the folder where data is available and final results will be stored", metavar="character"),
    make_option(c("-q", "--qc"), type="character", default=".",
                  help="path to the quality check folder where intermediary results will be stored", metavar="character"),
    make_option(c("-k", "--skip"), type="character", default="no",
                  help="skip filtering bad frames based on blank wells", metavar="character")
)

# Parse options
opt_parser <- OptionParser(option_list = option_list)
opt <- parse_args(opt_parser)

# Check mandatory arguments
if (is.null(opt$file)){
  print_help(opt_parser)
  stop("At least one argument must be supplied (input file).", call.=FALSE)
}

filename     <- basename(opt$file) %>% tools::file_path_sans_ext()
filename_img <- stringr::str_replace(filename, "%", "%%")

if (opt$skip == "no" | opt$skip == "n") {
    skip <- FALSE
} else if (opt$skip == "yes" | opt$skip == "y") {
    skip <- TRUE
} else {
    stop("Skip option accepts only \"y\", \"yes\", \"n\" and \"no\" values.", call.=FALSE)
}

# Graphic options
qc_fd <- opt$qc



#=================#
# Data processing #
#=================#

if( ! dir.exists(qc_fd)) { dir.create(qc_fd, recursive = TRUE) }

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

if (skip) {
    bad_wells <- rep(FALSE, ncol(mytable) - 1)
} else {
    # Detecting unaligned frame
    mybad_frame_bk <- (mytable[myblank,2:ncol(mytable)] > (mytable[myblank,2:ncol(mytable)] %>% unlist() %>% sd)) %>% colSums() == sum(myblank)
    mytable.tmp <- mytable[, 2:ncol(mytable)]
    mytable.tmp[, mybad_frame_bk] <- 0
    
    # Compute normalized distance from the mean
    mysd <- apply(mytable.tmp[myblank, ], 1, function(x) ( (x - mean(x)) / sqrt(mean(x))) )
    mysd[ ! is.finite(mysd) ] <- 0

    # Filter on max distance to the mean and invert coefficient of variation
    bad_wells <- apply(mysd, 1, max) >= 10 | apply(mysd, 1, sd) >= 4 
    bad_wells_tmp <- ((apply(mysd, 1, function(x) mean(x) / sd(x)) ) %>% abs() %>% round() ) >= 4
    bad_wells_tmp[ is.na(bad_wells_tmp) ]  <- FALSE
    bad_wells <- bad_wells | bad_wells_tmp | mybad_frame_bk
}

# Keep only good wells
bs <- apply(mytable[, 2:ncol(mytable)][, ! bad_wells], 1, function(x) mean(x))
names(bs) <- mytable[,1]


#-------------#
# Final table #
#-------------#

cs <- merge(mylayout, as.data.frame(bs), by.x=1, by.y="row.names")

cs2 <- cs[ ! myblank, ] %>% droplevels()

# Write table with average values
write.table(cs2, paste0(opt$prefix, "/", filename, "_mean.tsv"), row.names = FALSE, sep = "\t")

# Write report
report <- c(
    paste("Total number of frames:",     length(bad_wells)),
    paste("Number of retained frames:",  sum(!bad_wells)),
    paste("Number of discarded frames:", sum(bad_wells))
)
write(report, paste0(qc_fd, "/frame report.txt"))



#=========#
# Figures #
#=========#

#-------------------------#
# Global group comparison #
#-------------------------#

# Including blank wells for quality check
pdf(paste0(qc_fd, "/", filename_img, "_boxplot.pdf"))
boxplot(cs[,3] ~ cs[,2], xlab = "Population", ylab = "Movement index")
dev.off()

# Final boxplot
pdf(paste0(opt$prefix, "/", filename_img, "_boxplot.pdf"))
boxplot(cs2[,3] ~ cs2[,2], xlab = "Population", ylab = "Movement index")
dev.off()


#--------------------------#
# Average movement by well #
#--------------------------#

# Including blank wells for quality check
pdf(paste0(qc_fd, "/", filename_img, "_mean.pdf"))
raw_map(data = cs[,3],
        well = cs[,1],
        plate = 96) +
    scale_fill_gradient(low = "white", high = "black")
dev.off()

# Final plate plot
pdf(paste0(opt$prefix, "/", filename_img, "_mean_final.pdf"))
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

qc_fd_d <- paste0(qc_fd, "/discarded images/")
qc_fd_r <- paste0(qc_fd, "/retained images/")

if( ! dir.exists(qc_fd_d)) { dir.create(qc_fd_d, recursive = TRUE) }
if( ! dir.exists(qc_fd_r)) { dir.create(qc_fd_r, recursive = TRUE) }

# Output graph for each column of the input table
for (i in 2:(ncol(mytable))) {

    if (bad_wells[i-1]) {
        png(paste0(qc_fd_d, filename_img, "_", colnames(mytable)[i], ".png"))
        p <- raw_map(data = mytable[, i],
                well = mytable[, 1],
                plate = 96) +
            scale_fill_gradient(low = "white", high = "black", limits = range(mytable[, 2:(ncol(mytable)-1)]))
    } else {
        png(paste0(qc_fd_r, filename_img, "_", colnames(mytable)[i], ".png"))
        p <- raw_map(data = mytable[, i],
                well = mytable[, 1],
                plate = 96) +
            scale_fill_gradient(low = "white", high = "black", limits = range(mytable[, 2:(ncol(mytable)-1)]))
    }

    print(p)
    dev.off()
}
