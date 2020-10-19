#!/bin/bash
# Title: 
# Version: 0.4
# Author: Frédéric CHEVALIER <fcheval@txbiomed.org>
# Created in: 2020-07-15
# Modified in: 2020-10-18
# Licence : GPL v3



#======#
# Aims #
#======#

aim=""



#==========#
# Versions #
#==========#

# v0.4 - 2020-10-18: add frame alignment step / update path to diff script / remove unnecessary code
# v0.3 - 2020-10-10: use mask to identify well / replace RandIndex by a simpler image difference index / improve input file check
# v0.2 - 2020-10-07: negate and threshold image during the equalization step
# v0.1 - 2020-09-14: add equalization step
# v0.0 - 2020-07-15: creation

version=$(grep -i -m 1 "version" "$0" | cut -d ":" -f 2 | sed "s/^ *//g")



#===========#
# Functions #
#===========#

# Usage message
function usage {
    echo -e "
    \e[32m ${0##*/} \e[00m -i|--in file -o|--output file -a|--start value -p|--stop value -n|--int value -t|--trsh value -h|--help

Aim: $aim

Version: $version

Options:
    -i, --in        input video file
    -o, --output    name of the output file [default: RandIndex_table.tsv]
    -a, --start     video time in second at which to start the analysis (integer) [default: 0]
    -p, --stop      video time in second at which to stop the analysis (integer) [default: 180]
    -n, --int       interval in second for sampling frame (integer) [default: 5]
    -t, --trsh      percentage of thresholding for well recognition (integer) [default: 60]
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
test_dep align_image_stack



#===========#
# Variables #
#===========#

# Options
while [[ $# -gt 0 ]]
do
    case $1 in
        -i|--in     ) movie="$2"  ; shift 2 ;;
        -o|--output ) output="$2" ; shift 2 ;;
        -a|--start  ) start="$2"  ; shift 2 ;;
        -p|--stop   ) stop="$2"   ; shift 2 ;;
        -n|--int    ) int="$2"    ; shift 2 ;;
        -t|--trsh   ) trsh="$2"   ; shift 2 ;;
        -h|--help   ) usage ; exit 0 ;;
        *           ) error "Invalid option: $1\n$(usage)" 1 ;;
    esac
done


# Check the existence of obligatory options
[[ -z "$movie" ]] && error "The option input is required. Exiting...\n$(usage)" 1
[[ ! -s "$movie" ]] && error "The input video does not exist or is empty. Exiting...\n$(usage)" 1
[[ ! $(mimetype -bL "$movie" | grep -i video) ]] && error "The input is not a video file. Exiting...\n$(usage)" 1

# Check output variable and files
[[ -z "$output" ]] && output="RandIndex_table.tsv"
[[ -f "$output" ]] && error "Output file $output exists already. Exiting..." 1

# Default values for video time
[[ -z "$start" ]] && start=0
[[ -z "$stop" ]]  && stop=180
[[ -z "$int" ]]   && int=5
[[ -z "$trsh" ]]  && trsh=60

# Check related values to video time
[[ ! $(grep -x "[[:digit:]]*" <<<"$start") || ! $(grep -x "[[:digit:]]*" <<<"$int") || ! $(grep -x "[[:digit:]]*" <<<"$stop") ]] && error "The option start, stop and int must be integers. Exiting..." 1
[[ "$start" -gt "$stop" ]] && error "The option start is greater than stop. Exiting..." 1

# Check thresholding value
[[ ! $(grep -x "[[:digit:]]*" <<<"$trsh") || $trsh -lt 0 || $trsh -gt 100 ]] && error "The option trsh must be a number between 0 and 100. Exiting..." 1

# Directory variables
dir_frames=frames
dir_wells=wells
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

# Check max frame
myseq=$(seq -w $start $int $stop)
stop_real=$(tail -n 1 <<<"$myseq")
if [[ "$stop_real" -ne "$stop" ]]
then
    warning "Final frame will be at ${stop_real}s."
    stop=$stop_real
fi

# Extract frames
## source: https://stackoverflow.com/a/28321986 (it was demonstrated to be faster)
tag=1
for i in $myseq
do
    ProgressBar 10#$i $stop
	ffmpeg -y -accurate_seek -ss $i -i "$movie" -frames:v 1 "$dir_frames/${i}-${tag}.png" &>> "$log_movie"
    [[ $? -ne 0 ]] && error "Please see $log_movie for details. Exiting..." 1
    [[ $tag -eq 1 ]] && tag=2 || tag=1
done

# Align frames
info "Realigning images. This may take time..."
align_image_stack -a "$dir_frames/" --use-given-order "$dir_frames/"*.png &> "$log_wells"

# Rename aligned frames to the original name
ls_fl=$(paste <(find "$dir_frames/" -mindepth 1 -name *tif) <(find "$dir_frames/" -mindepth 1 -name *png | sort | sed "s/png$/tif/"))
while read l
do
    mv "$(cut -f 1 <<< "$l")" "$(cut -f 2 <<< "$l")"
done <<< "$ls_fl"

# Remove unaligned frames
rm "$dir_frames/"*.png

# Generate mask
info "Generating mask for well extraction."
flist=$(ls -1d "$dir_frames"/*)
length=$(wc -l <<< "$flist")
file=$(sed -n "1p" <<< "$flist")
convert "$file" -equalize -negate -threshold $trsh% "$(dirname "$file")/mask_ent.tif"
for i in $(seq 1 $length)
do
    #ProgressBar 10#$i $length
    file=$(sed -n "${i}p" <<< "$flist")
	cp -a "$(dirname "$file")/mask_ent.tif" "${file%.*}_ent.tif"
done

# Remove mask
rm "$(dirname "$file")/mask_ent.tif"


#---------------#
# Analyze wells #
#---------------#

info "Extracting individual wells. This may take a while..."
cellprofiler -c -r -p "$dir_pipelines/Single Worm Output.cppipe" -i "$dir_frames" -o "$dir_wells" &> "$log_wells"
[[ $? -ne 0 ]] && error "Please see $log_wells for details. Exiting..." 1


#--------------------------#
# Compute well differences #
#--------------------------#

info "Comparing wells over time."
dlist=($(find "$dir_wells/" -mindepth 1 -type d | sort))
dend=$(( ${#dlist[@]} - 1 ))
for ((i = 0 ; i < $dend ; i++))
do
    j=$(($i + 1))
    ProgressBar 10#$j $dend
    "$(dirname $0)/diff_image.sh" ${dlist[$i]} ${dlist[$j]} "$dir_wells/${dlist[$i]##*/}-${dlist[$j]##*/}.tab"
done


#----------------------#
# Generate final table #
#----------------------#

info "Generating final table..."

ls_fl=($(find "$dir_wells" -mindepth 1 -type f -name *.tab | sort))

for i in ${!ls_fl[@]}
do
    ProgressBar 10#$(($i + 1)) ${#ls_fl[@]}
    
    if [[ $i == 0 ]]
    then
        myheader="Well\t$(sed -r "s|.*/(.*).tab|\1|g" <<< "${ls_fl[$i]}")"
        mymean=$(cat <(echo "$myheader") <(sed "s| |\t|g" "${ls_fl[$i]}" | cut -f 1-2))
        myerror=$(cat <(echo "$myheader") <(sed "s| |\t|g" "${ls_fl[$i]}" | cut -f 1,3))
    else
        myheader="$(sed -r "s|.*/(.*).tab|\1|g" <<< "${ls_fl[$i]}")"
        mymean=$(paste <(echo "$mymean") <(cat <(echo "$myheader") <(cut -d " " -f 2 "${ls_fl[$i]}")))
        myerror=$(paste <(echo "$myerror") <(cat <(echo "$myheader") <(cut -d " " -f 3 "${ls_fl[$i]}")))
    fi

done

echo -e "$mymean"  >> "${output}_mymean.tsv"
echo -e "$myerror" >> "${output}_myerror.tsv"


#-------#
# Clean #
#-------#

clean_up "$dir_log"

exit 0
