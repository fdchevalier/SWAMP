#!/bin/bash
# Title: best-grid.sh
# Version: 0.1
# Author: Frédéric CHEVALIER <fcheval@txbiomed.org>
# Created in: 2020-10-11
# Modified in: 2020-10-22 
# Licence : GPL v3



#======#
# Aims #
#======#

aim="Determine the best grid by testing several thresold values."



#==========#
# Versions #
#==========#

# v0.1 - 2020-10-22: add png to tif convertion / replace info message / remove unnecessary code
# v0.0 - 2020-10-11: creation

version=$(grep -i -m 1 "version" "$0" | cut -d ":" -f 2 | sed "s/^ *//g")



#===========#
# Functions #
#===========#

# Usage message
function usage {
    echo -e "
    \e[32m ${0##*/} \e[00m -i|--in file -a|--start value -p|--stop value -n|--int value -t|--time value -h|--help

Aim: $aim

Version: $version

Options:
    -i, --in        input video file
    -a, --start     first threshold value of the tested range (integer) [default: 0]
    -p, --stop      last threshold value of the tested range (integer) [default: 100]
    -n, --int       number used to increment threshold values within the defined range (integer) [default: 5]
    -t, --time      video time in second corresponding to the frame used to draw the grid (integer)
    -h, --help      this message
    "
}


# Info message
function info {
    if [[ -t 1 ]]
    then
        echo -e "\e[32mInfo:\e[00m $1"
    else
        echo -e "Info: $1"
    fi
}


# Warning message
function warning {
    if [[ -t 1 ]]
    then
        echo -e "\e[33mWarning:\e[00m $1"
    else
        echo -e "Warning: $1"
    fi
}


# Error message
## usage: error "message" exit_code
## exit code optional (no exit allowing downstream steps)
function error {
    if [[ -t 1 ]]
    then
        echo -e "\e[31mError:\e[00m $1"
    else
        echo -e "Error: $1"
    fi

    if [[ -n $2 ]]
    then
        exit $2
    fi
}


# Dependency test
function test_dep {
    which $1 &> /dev/null
    if [[ $? != 0 ]]
    then
        error "Command $1 not found. Exiting..." 1
    fi
}


# Progress bar
## Usage: ProgressBar $mystep $myend
function ProgressBar {
    if [[ -t 1 ]]
    then
        # Process data
        let _progress=(${1}*100/${2}*100)/100
        let _done=(${_progress}*4)/10
        let _left=40-$_done
        # Build progressbar string lengths
        _fill=$(printf "%${_done}s")
        _empty=$(printf "%${_left}s")

        # Build progressbar strings and print the ProgressBar line
        # Output example:
        # Progress : [########################################] 100%
        #printf "\rProgress : [${_fill// /=}${_empty// / }] ${_progress}%%"
        printf "\r\e[32mProgress:\e[00m [${_fill// /=}${_empty// / }] ${_progress}%%"

        [[ ${_progress} == 100 ]] && echo ""
    fi
}


# Clean up function for trap command
## Usage: clean_up file1 file2 ...
function clean_up {
    rm -rf $@
    exit 1
}



#==============#
# Dependencies #
#==============#

test_dep ffmpeg
test_dep convert
test_dep cellprofiler



#===========#
# Variables #
#===========#

# Options
while [[ $# -gt 0 ]]
do
    case $1 in
        -i|--in     ) movie="$2"  ; shift 2 ;;
        -a|--start  ) start="$2"  ; shift 2 ;;
        -p|--stop   ) stop="$2"   ; shift 2 ;;
        -n|--int    ) int="$2"    ; shift 2 ;;
        -t|--time   ) time="$2"   ; shift 2 ;;
        -h|--help   ) usage ; exit 0 ;;
        *           ) error "Invalid option: $1\n$(usage)" 1 ;;
    esac
done


# Check the existence of obligatory options
[[ -z "$movie" ]] && error "The option input is required. Exiting...\n$(usage)" 1

# Default values for video time
[[ -z "$start" ]] && start=0
[[ -z "$stop" ]]  && stop=100
[[ -z "$int" ]]   && int=5

# Check related values to video time
[[ ! $(grep -x "[[:digit:]]*" <<<"$start") || ! $(grep -x "[[:digit:]]*" <<<"$int") || ! $(grep -x "[[:digit:]]*" <<<"$stop") ]] && error "The option start, stop and int mut be integers. Exiting..." 1
[[ "$start" -gt "$stop" ]] && error "The option start is greater than stop. Exiting..." 1

# Check thresholding values
[[ ! $(grep -x "[[:digit:]]*" <<<"$start") || $start -lt 0 || $start -gt 100 ]] && error "The option start must be a number between 0 and 100. Exiting..." 1
[[ ! $(grep -x "[[:digit:]]*" <<<"$stop") || $stop -lt 0 || $stop -gt 100 ]] && error "The option stop must be a number between 0 and 100. Exiting..." 1


# Directory variables
dir_frames=frames_test
dir_wells=grid_test
dir_log=$(mktemp -d)
dir_pipelines="$(dirname $0)/cellprofiler_pipelines"

# Log variables
log_movie="$dir_log/log_movie"
log_wells="$dir_log/log_wells"



#============#
# Processing #
#============#

# Trap function
trap "clean_up $dir_frames $dir_wells $dir_log" SIGINT SIGTERM    # Clean_up function to remove tmp files

#--------------------#
# Output directories #
#--------------------#

[[ ! -d "$dir_frames" ]] && mkdir -p "$dir_frames"
[[ ! -d "$dir_wells" ]]  && mkdir -p "$dir_wells"


#--------------#
# Movie frames #
#--------------#

info "Extracting frames..."

# Extract frames
## source: https://stackoverflow.com/a/28321986 (it was demonstrated to be faster)
ffmpeg -y -accurate_seek -ss $time -i "$movie" -frames:v 1 "$dir_frames/$time.png" &>> "$log_movie"

# Convert png to tif
convert "$dir_frames/$time.png" "$dir_frames/$time.tif"
rm "$dir_frames/$time.png"

info "Identifying grid for each threshold..."
# Store frame
flist=$(ls -1d "$dir_frames"/*)
length=$(wc -l <<< "$flist")
file=$(sed -n "1p" <<< "$flist")

# Run pipeline for each threshold
myseq=$(seq -w $start $int $stop)
stop_real=$(tail -n 1 <<<"$myseq")
for i in $myseq
do
    ProgressBar $(( 10#$i + 1 )) ${#myseq[@]}
    convert "$file" -equalize -negate -threshold ${myseq[$i]}% "$(dirname "$file")/mask_ent.tif"

    cellprofiler -c -r -p "$dir_pipelines/Grid determinator.cppipe" -i "$dir_frames" -o "$dir_wells/" &> "$log_wells"
    # [[ $? -ne 0 ]] && error "Please see $log_wells for details. Exiting..." 1

    [[ -f "$dir_wells/$time.png" ]] && mv "$dir_wells/${time}.png" "$dir_wells/${time}_${myseq[$i]}.png"
done

# Clean
rm -R "$dir_frames"

exit 0
