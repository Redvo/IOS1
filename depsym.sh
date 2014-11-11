#!/bin/bash

#
# Author: Lukáš Rendvanský, xrendv00
# Email: xrendv00@stud.fit.vutbr.cz
# Project: IOS, Project 1
# Date: 25.3.2014
# Description: Script prints dependencies between
# object files based on defined and used symbols.
#

help_msg(){
	echo -e "\nScript prints dependencies between object files based on defined and used symbols."
	echo -e "\nUsage: depsym.sh [-h] [-g] [-r OBJECT_ID|-d OBJECT_ID] FILE"
	echo -e "\t-h -- Prints this error message."
	echo -e "\t-g -- Prints all dependencies in .gv graph language."
	echo -e "\t-r OBJECT_ID -- Prints only dependencies where OBJECT_ID = OBJ2."
	echo -e "\t-d OBJECT_ID -- Prints only dependencies where OBJECT_ID = OBJ1."
	echo -e "\tFILE -- Object file/files (separated with whitespace) to process.\n"
	exit 1
}

error_msg(){
	echo "An error occurred. Run with parameter -h for help."
	exit 1
}

# Replace -> - with _ | + with P | . with D 
replace(){
	local s="$1"
	s="${s//./D}"
	s="${s//-/_}"
	s="${s//+/P}"
	echo "$s"
}

# Tell GETOPTS to not to write it's own error messages
OPTERR=0

# Store total number of arguments
ARGC=$#

# Bool values to test which arguments were set
GSET=false
RSET=false
DSET=false

# Argument OBJECT_ID
OBJECT_ID=""

# Check if there are any arguments.
if [[ $ARGC -eq 0 ]]; then
	error_msg
fi

# Get and check parameteres with GETOPTS
# Set bool variables
while getopts gpr:d:h options
do
    case "$options" in
	    (g) if [[ "$GSET" == false ]]; then
	    		GSET=true
	    	else
	    		error_msg
	    	fi
	    	;;
	    (r) if [[ "$DSET" == false ]] && [[ "$OPTARG" != "" ]]; then
	    		RSET=true
	    		OBJECT_ID="$OPTARG" 
	    	else
	    		error_msg
	    	fi
	    	;;
	    (d) if [[ "$RSET" == false ]] && [[ "$OPTARG" != "" ]]; then
	    		DSET=true
	    		OBJECT_ID="$OPTARG" 
	    	else
				error_msg
	    	fi
	    	;;
	    (h) help_msg
	    	;;
	    (*) error_msg
	    	;;
    esac
done

# Shift arguments by 1
shift $(($OPTIND - 1))

file_list="$@"

# Check if at least one filename has been set
if [[ "$1" == "" ]]; then
	error_msg
fi

#
# Debuging - print which arguments and filenames were set
#
if false; then

	echo -e "-g set: $GSET\n-p set: $PSET\n-r set: $RSET\n-d set: $DSET\nFunction : $OBJECT_ID\n"
	echo -e "FILENAMES:\n"

	for FILENAME in "$@" 
	do
		echo -e "\t - $FILENAME\n"
	done

fi

# Check if all filenames exist
for FILENAME in "$@" 
do
	if [[ ! -f "$FILENAME" ]]; then
    		echo "Fille $FILENAME doesn't exist!"
    		exit 1
	fi
done

# Regular expression to match filenames
REGEXFILE="^.*\.o:"
# Regular expression to match OBJECT 1
REGEX1="^[UTBCGD] .*"
# Regular expression to match OBJECT 2
REGEX2="^[a-fA-F0-9]* [UTBCGD] .*"

# Create variables for storing OBJ1 and OBJ2 symbols
# with filenames
obj1_list=""
obj2_list=""

labels=()
i=0
match=false

for FILENAME in "$@" 
do

	# Create dependencies of symbols in each file and save it to variable
	file_nm="`nm $FILENAME`"

	# Read variable file_nm line by line
	while read -r line
	do

		if echo "$line"|grep -E -q "$REGEXFILE"; then
			NAME=$(echo -n "$line")
			continue
		fi

		# Fill list with objects 1
		if echo "$line"|grep -E -q "$REGEX1"; then
			OBJ1=$(echo -n "$line"|cut -d " " -f2)
			obj1_list+="$(echo "[$FILENAME] -> ($OBJ1)")"$'\n'
			continue
		fi

		# Fill list with objects 2
		if echo "$line"|grep -E -q "$REGEX2"; then
			OBJ2=$(echo -n "$line"|cut -d " " -f3)
			obj2_list+="$(echo "[$FILENAME] -> ($OBJ2)")"$'\n'
			continue
		fi

	# Reading lines from variable 
	done <<< "$file_nm"

done

if [[ "$GSET" == true ]]; then
	echo "digraph GSYM {"
fi

# Read variable obj1_list line by line
while read -r line
do

	# Cut filenames and symbols from brackets
	object1=$(echo "$line"|cut -d "[" -f2 | cut -d "]" -f1)
	symbol=$(echo "$line"|cut -d "(" -f2 | cut -d ")" -f1)
	tmp_object=$(echo "$obj2_list"|grep -E "^\[.*\] -> \($symbol\)")
	object2=$(echo "$tmp_object"|cut -d "[" -f2 | cut -d "]" -f1)

	# Add extra labels to end of output if we want to creat graph
	if [[ "$GSET" == true ]]; then
		
		for label in "${labels[@]}"
		do
			if [[ "$label" == "$object1" ]]; then
				match=true
			fi
		done

		if [[ "$match" == false ]]; then
			labels+=("$object1")
		fi

		match=false

	fi

	# If object is not empty ->
	if [[ "$object2" != "" ]]; then
		
		# If none of -r or -d is set, print everything
		if [[ "$RSET" == false ]] && [[ "$DSET" == false ]]; then
			
			if [[ "$GSET" == false ]]; then
				echo "$object1 -> $object2 ($symbol)"
			else
				object1=$(replace $object1)
				object2=$(replace $object2)
				echo "$object1 -> $object2 [label=\"$symbol\"];"
			fi

		fi

		# If -r is set, print only dependencies where OBJECT_ID = OBJ2
		if [[ "$RSET" == true ]] && [[ "$OBJECT_ID" == "$object2" ]]; then

			if [[ "$GSET" == false ]]; then
				echo "$object1 -> $object2 ($symbol)"
			else
				object1=$(replace $object1)
				object2=$(replace $object2)
				echo "$object1 -> $object2 [label=\"$symbol\"];"
			fi

		fi

		# If -d is set, print only dependencies where OBJECT_ID = OBJ1
		if [[ "$DSET" == true ]] && [[ "$OBJECT_ID" == "$object1" ]]; then
		
			if [[ "$GSET" == false ]]; then
				echo "$object1 -> $object2 ($symbol)"
			else
				object1=$(replace $object1)
				object2=$(replace $object2)
				echo "$object1 -> $object2 [label=\"$symbol\"];"
			fi
		
		fi

	fi

# Reading lines from variable 
done <<< "$obj1_list"

# Add last labels for graph
if [[ "$GSET" == true ]]; then
	
	for label in "${labels[@]}"
	do
		if [[ "$label" != "" ]]; then
			label_r="$(replace $label)"
			echo "$label_r [label=\"$label\"];"
		fi
	done

	echo "}"
fi

exit 0

# End of file depsym.sh
