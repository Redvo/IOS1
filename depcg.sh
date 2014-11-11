#!/bin/bash

#
# Author: Lukáš Rendvanský, xrendv00
# Email: xrendv00@stud.fit.vutbr.cz
# Project: IOS, Project 1
# Date: 25.3.2014
# Description: Script prints dependencies between
# functions in binary files.
#

help_msg(){
	echo -e "\nScript prints dependencies between functions in binary files."
	echo -e "\nUsage: depcg.sh [-h] [-g] [-p] [-r FUNCTION_ID|-d FUNCTION_ID] FILE"
	echo -e "\t-h -- Prints this error message."
	echo -e "\t-g -- Prints all dependencies in .gv graph language."
	echo -e "\t-p -- Prints salso dependencies based on functions from shared libraries."
	echo -e "\t-r FUNCTION_ID -- Prints only functions that depends on function called FUNCTION_ID."
	echo -e "\t-d FUNCTION_ID -- Prints only functions that function called FUNCTION_ID depends on."
	echo -e "\tFILE -- Binary file/files (separated with whitespace) to process.\n"
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
PSET=false
RSET=false
DSET=false

# Argument FUNCTION_ID
FUNCTION_ID=""

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
	    (p) if [[ "$PSET" == false ]]; then
	    		PSET=true
	    	else
	    		error_msg
	    	fi
	    	;;
	    (r) if [[ "$DSET" == false ]] && [[ "$OPTARG" != "" ]]; then
	    		RSET=true
	    		FUNCTION_ID="$OPTARG" 
	    	else
	    		error_msg
	    	fi
	    	;;
	    (d) if [[ "$RSET" == false ]] && [[ "$OPTARG" != "" ]]; then
	    		DSET=true
	    		FUNCTION_ID="$OPTARG" 
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

# Check if at least one filename has been set
if [[ "$1" == "" ]]; then
	error_msg
fi

# Used for debuging - print which arguments and filenames were set
if false; then

	echo -e "-g set: $GSET\n-p set: $PSET\n-r set: $RSET\n-d set: $DSET\nFunction : $FUNCTION_ID\n"
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

# Regular expression to match caller
REGEX1="^[a-fA-F0-9]* <.*>:"

# Regular expression to match callee
if [[ "$PSET" == true ]]; then
	# callee with @plt suffix
	REGEX2="^.*(call).*<.*>"
	REGEX2NOT="^.*(call).*<.*+0x[0-9]*>"
	#REGEX2="^.*(callq).*<.*>"
else
	# callee without @plt suffix
	REGEX2="^.*(call).*<[^@]*>"
	REGEX2NOT="^.*(call).*<[^@]*+0x[0-9]*>"
	#REGEX2="^.*(callq).*<[^@]*>"
fi

tmp=""

# This code is executed for each file 
for FILENAME in "$@" 
do

	# Create disassembled code of file and save it to variable
	file_objdump="`objdump -d -j .text $FILENAME`"

	# Read variable line by line
	while read -r line
	do

		# If line matches regular expression of caller, cut it from
		# < > brackets and save it to variable 
		if echo "$line"|grep -E -q "$REGEX1"; then
			caller=$(echo -n "$line"|cut -d "<" -f2 | cut -d ">" -f1)
			caller=$(replace $caller)
			continue
		fi

		# If line matches regular expression of callee, cut it from
		# < > brackets and save it to variable 
		if echo "$line"|grep -E "$REGEX2"|grep -q -E -v "$REGEX2NOT"; then

			callee=$(echo "$line"|cut -d "<" -f2 | cut -d ">" -f1)

			# If parameters -p and -g are set, replace @plt with _PLT
			if [[ "$PSET" == true ]] && [[ "$GSET" == true ]]; then
				callee="${callee//\@plt/_PLT}"

				# If callee contains dots, replace it with underscore
				# because .gv language print error on dots in names.
				callee=$(replace $callee)
			fi

			# If parameter -r is not set ->
			if [[ "$RSET" == false ]]; then

				# If parameter -d is set and caller matches FUNCTION_ID ->
				if [[ "$DSET" == true ]] && [[ "$FUNCTION_ID" == "$caller" ]]; then

					# Look if entry already exist in tmp and append
					# it if not, or continue to next line.
					if echo "$tmp"|grep -Eq "$caller -> $callee"; then	
						continue
					else
						tmp+=$(echo "$caller -> $callee\n")
						continue
					fi

				# If parameter -d is not set ->
				elif [[ "$DSET" == false ]]; then

					# Look if entry already exist in tmp and append
					# it if not, else continue to next line.
					if echo "$tmp"|grep -Eq "$caller -> $callee"; then	
						continue
					else
						tmp+=$(echo "$caller -> $callee\n")
						continue
					fi
				
				# Else continue (e.g. -d is set but caller and FUNCTION_ID doesn't match)
				else

					continue

				fi

			# Else if parameter -r is set ->
			else

				# If callee matches FUNCTION_ID ->
				if [[ "$FUNCTION_ID" == "$callee" ]]; then

					# Look if entry already exist in tmp and append
					# it if not, else continue to next line.
					if echo "$tmp"|grep -Eq "$caller -> $callee"; then	
						continue
					else
						tmp+=$(echo "$caller -> $callee\n")
						continue
					fi

				# Else continue
				else

					continue

				fi

			fi

		fi

	# Reading lines from variable 
	done <<< "$file_objdump"

done


# If parameter -g is set, print content with header and
# footer of .gv graph language, else print only content.	
if [[ "$GSET" == true ]]; then
	echo "digraph CG {"
	echo -e "${tmp%\\n}"| sed "s/.*/&;/"
	echo "}"
else
	echo -e "${tmp%\\n}"
fi

exit 0

# End of file depcg.sh
