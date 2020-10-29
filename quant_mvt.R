#!/usr/bin/env Rscript
# Title: quant_mvt.R
# Version: 0.0
# Author: Frédéric CHEVALIER <fcheval@txbiomed.org>
# Created in: 2020-10-29
# Modified in: 
# Licence: GPL v3



#==========#
# Comments #
#==========#

aim <- "Analyze table of movement index (absolute error) between well images and output table and graphs."



#==========#
# Versions #
#==========#

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
                  help="plate layout file", metavar="character")
)

# Parse options
opt_parser <- OptionParser(option_list = option_list)
opt <- parse_args(opt_parser)

# Check mandatory arguments
if (is.null(opt$file)){
  print_help(opt_parser)
  stop("At least one argument must be supplied (input file).n", call.=FALSE)
}

# Graphic options
graph_fd <- "graphs/"
#theme_set(theme_classic())



#=================#
# Data processing #
#=================#

# Load data
mytable  <- read.delim(opt$file)
mylayout <- read.delim(opt$layout)

# Identify blank wells
myblank <- mylayout[,2] == "blank"

#----------------------------#
# Identify problematic wells #
#----------------------------#

# Normalize with the max: this is good to increase differences and separate blank from worms but is problematic if there is a spike (image shift) somewhere.
#bs <- apply(mytable[,2:ncol(mytable)], 1, function(x) sum(x*max(x)))

# Alternative: this was efficient to determine the two empty wells. However, noise was undistinguishable from low moving worms (is this bad?)
# bs <- apply(mytable[,2:ncol(mytable)], 1, function(x) sum(x*(max(x)/min(x))))
# bs <- apply(mytable[,2:ncol(mytable)], 1, function(x) sum(x))

# Use of standard deviation
# mysd <- apply(mytable[,2:ncol(mytable)], 2, function(x) sd(x[myblank], na.rm=T) < 80)
# mysd <- apply(mytable[,2:ncol(mytable)], 2, function(x) ( (x[myblank] - mean(x[myblank])) / sd(x[myblank]) ) %>% sd())
# mysd <- apply(mytable[myblank,2:ncol(mytable)], 1, function(x) ( (x - mean(x)) / sd(x)) ) # Z-score per well

mysd <- apply(mytable[myblank,2:ncol(mytable)], 1, function(x) ( (x - mean(x)) / sqrt(mean(x))) ) # Normalized distance from the mean
mysd[ ! is.finite(mysd) ] <- 0
# bad_wells <- ((mysd > 3) %>% rowSums) > 0
# bad_wells <- apply(mysd, 1, max) > 10
## Filter on max, sd and invert coefficient of variation
bad_wells <- apply(mysd, 1, max) >= 10 | apply(mysd, 1, sd) >= 4 | ((apply(mysd, 1, function(x) mean(x) / sd(x)) ) %>% abs() %>% round() ) >= 4

# bad_wells <- rep(FALSE, length(2:ncol(mytable)))
bs <- apply(mytable[, 2:ncol(mytable)][, ! bad_wells], 1, function(x) mean(x))


#-------------#
# Final table #
#-------------#

cs <- cbind(mylayout, bs)
cs[, ncol(cs) + 1] <- num_to_well(1:96) %>% rev()
cs2 <- cbind(num_to_well(1:96) %>% rev(), bs)[ ! myblank, ]

# Write table with average values
write.table(cs2, "b_mean.tsv", row.names = FALSE, sep = "\t")



#=========#
# Figures #
#=========#

if( ! dir.exists(graph_fd)) { dir.create(graph_fd, recursive = TRUE) }

#-------------------------#
# Global group comparison #
#-------------------------#

png(paste0(graph_fd, opt$file, "_boxplot.png"))
boxplot(cs[,3] ~ cs[,2])
dev.off()


#--------------------------#
# Average movement by well #
#--------------------------#

png(paste0(graph_fd, opt$file, "_mean.png"))
raw_map(data = cs[,3],
        well = cs[,4],
        plate = 96) +
#    ggtitle("Example 384-well plate") +
    scale_fill_gradient(low = "white", high = "black")
dev.off()

# pdf(paste0(graph_fd, opt$file, "_mean_final.pdf"))
# cs.tmp <- cs
# # cs.tmp[ cs.tmp[,2] == "blank", 3] <- 0
# myclr  <- rep(NA, nrow(cs))
# myfill <- rep(NA, nrow(cs))
# myclr[ cs[,2] == "blank" ]  <- "grey90"
# myfill[ cs[,2] == "blank" ] <- "white"
# raw_map(data = cs.tmp[,3],
#         well = cs.tmp[,4],
#         plate = 96) +
# #    ggtitle("Example 384-well plate") +
#     geom_point(fill = myfill, colour = myclr, size = 10, shape = 21, stroke = 1.1) +
#     scale_fill_gradient(low = "white", high = "black") +
#     theme(panel.grid.minor = element_blank())
# dev.off()

# pdf(paste0(graph_fd, opt$file, "_mean_final.pdf"))
# cs.tmp <- cs[ cs[,2] != "blank", ]
# # cs.tmp[ cs.tmp[,2] == "blank", 3] <- 0
# myclr  <- rep(NA, nrow(cs))
# myfill <- rep(NA, nrow(cs))
# myclr[ cs[,2] == "blank" ]  <- "grey90"
# myfill[ cs[,2] == "blank" ] <- "white"
# raw_map(data = cs.tmp[,3],
#         well = cs.tmp[,4],
#         plate = 96) +
# #    ggtitle("Example 384-well plate") +
#     geom_point(fill = myfill, colour = myclr, size = 10, shape = 21) +
#     scale_fill_gradient(low = "white", high = "black") +
#     theme(panel.grid.minor = element_blank())
# dev.off()

pdf(paste0(graph_fd, opt$file, "_mean_final.pdf"))
cs.tmp <- cs
# cs.tmp[ cs.tmp[,2] == "blank", 3] <- 0
myclr  <- rep(NA, nrow(cs))
myfill <- rep(NA, nrow(cs))
myclr[ cs[,2] == "blank" ]  <- "grey20"
myfill[ cs[,2] == "blank" ] <- "white"
raw_map(data = cs.tmp[,3],
        well = cs.tmp[,4],
        plate = 96) +
#    ggtitle("Example 384-well plate") +
    # geom_point(fill = myfill, colour = myclr, size = 10, shape = 21) +
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
mytable[, ncol(mytable) + 1] <- num_to_well(1:96) %>% rev()
for (i in 2:(ncol(mytable)-1)) {

    if (bad_wells[i-1]) {
    png(paste0(graph_fd_d, opt$file, "_", colnames(mytable)[i], ".png"))
        p <- raw_map(data = mytable[, i],
                well = mytable[, ncol(mytable)],
                plate = 96) +
#    ggtitle("Example 384-well plate") +
            scale_fill_gradient(low = "white", high = "black", limits = range(mytable[, 2:(ncol(mytable)-1)]))
    } else {
        png(paste0(graph_fd_r, opt$file, "_", colnames(mytable)[i], ".png"))
        p <- raw_map(data = mytable[, i],
                well = mytable[, ncol(mytable)],
                plate = 96) +
#    ggtitle("Example 384-well plate") +
            scale_fill_gradient(low = "white", high = "black", limits = range(mytable[, 2:(ncol(mytable)-1)]))
    }

    print(p)
    dev.off()
}
