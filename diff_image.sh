#!/bin/bash
# Title: diff_image.sh 
# Version: 0.1
# Author: Frédéric CHEVALIER <fcheval@txbiomed.org>
# Created in: 2020-10-10
# Modified in: 2020-10-20
# Licence : GPL v3



#======#
# Aims #
#======#

aim="Compare a pair of images and determine how much difference (error) there is between them."



#==========#
# Versions #
#==========#

# v0.1 - 2020-10-20: change image comparison method to overcome background noise / improve listing of files
# v0.0 - 2020-10-10: creation

version=$(grep -i -m 1 "version" "$0" | cut -d ":" -f 2 | sed "s/^ *//g")



#===========#
# Functions #
#===========#

# Dependency test
function test_dep {
    which $1 &> /dev/null
    if [[ $? != 0 ]]
    then
        error "Command $1 not found. Exiting..." 1
    fi
}



#==============#
# Dependencies #
#==============#

test_dep compare



#===========#
# Variables #
#===========#

mydir_1="$1"
mydir_2="$2"

# output="$(basename "$(echo "$mydir_1")").tab"
output="$3"



#============#
# Processing #
#============#

# List file and check if the same sets are present
flist_1=$(ls -1d "$mydir_1"/* | sed "s|.*/||g" | sort -V)
flist_2=$(ls -1d "$mydir_2"/* | sed "s|.*/||g" | sort -V)

[[ "$flist_2" != "$flist_2" ]] && echo "List of files does not match."

flist="$flist_1"
length=$(wc -l <<< "$flist")

# Compute image differences
for i in $(seq 1 $length)
do
#    ProgressBar 10#$i $length
    myfile="$(sed -n "${i}p" <<< "$flist")"

    ## source: http://www.imagemagick.org/Usage/compare/#difference
    # mymetric=$(compare -metric AE -fuzz 10% "$mydir_1/$myfile" "$mydir_2/$myfile" null: 2>&1 | sed "s/[()]//g")
    mymetric=$(compare -metric AE -fuzz 7% "$mydir_1/$myfile" "$mydir_2/$myfile" null: 2>&1 | sed "s/[()]//g")

    echo "$myfile $mymetric" >> "$output"
done

exit 0
