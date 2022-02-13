#!/bin/bash

# Useful variables
RED_TXT='\033[0;31m'
GREEN_TXT='\033[0;32m'
GRAY_TXT='\033[1;30m'
BLUE_TXT='\033[0;34m'
YELLOW_TXT='\033[0;33m'
RESET_TXT='\033[0m'

CALL_DIR=$PWD
START_DIR=$PWD
RECURSIVE=NO

CURSOR_ROW=0
CURSOR_COL=0

DIRTY=()
DESYNCD=()
MISSING=()
DETACHED=()

# Useful functions
function getCursor()
{
	echo -e "\033[6n\c"
	read -sdR CURPOS
	CURPOS=${CURPOS#*[}
	arrIN=(${CURPOS//;/ })
	
	CURSOR_ROW=${arrIN[0]} 
	CURSOR_COL=${arrIN[1]} 
}

function moveCursor()
{
	COL_SHIFT=$1
	ROW_SHIFT=0
	
	if [ "$#" -gt 1 ]; then
		ROW_SHIFT=$2
	fi
	
	if [ $COL_SHIFT -lt 0 ]; then
		COL_SHIFT=${COL_SHIFT#-}
		CMD='\033['$COL_SHIFT'D'
		echo -e -n $CMD
	elif [ $COL_SHIFT -gt 0 ]; then
		CMD='\033['$COL_SHIFT'C'
		echo -e -n $CMD
	fi	
	
	if [ $ROW_SHIFT -lt 0 ]; then
		ROW_SHIFT=${ROW_SHIFT#-}
		CMD='\033['$ROW_SHIFT'A'
		echo -e -n $CMD
	elif [ $ROW_SHIFT -gt 0 ]; then
		CMD='\033['$ROW_SHIFT'B'
		echo -e -n $CMD
	fi
}

function print()
{
	POSITIONAL_ARGS=()
	LEVEL=1
	PADDING=-1
	COLOR=$RESET_TXT
	MSG=""
	NEWLINE=YES
	
	while [[ $# -gt 0 ]]; do
		case $1 in
			-l|--level)
			  LEVEL=$2
			  shift # past argument
			  shift # past value
			  ;;
			-p|--padding)
			  PADDING=$2
			  shift # past argument
			  shift # past value
			  ;;
			-c|--color)
			  COLOR="$2"
			  shift # past argument
			  shift # past value
			  ;;			
			-m|--msg)
			  MSG="$2"
			  shift # past argument
			  shift # past value
			  ;;
			-n|--nonewline)
			  NEWLINE=NO
			  shift # past argument
			  shift # past value
			  ;;
			-*|--*)
			  echo "Unknown option $1"
			  exit 1
			  ;;
			*)
			  POSITIONAL_ARGS+=("$1") # save positional arg
			  shift # past argument
			  ;;
		esac
	done
	
	if [ ${#POSITIONAL_ARGS[@]} -gt 0 ] && [ "$MSG" = "" ]; then
		MSG=${POSITIONAL_ARGS[0]}
	fi
	
	if [ $PADDING -lt 0 ]; then
		for (( c=0; c<$LEVEL; c++ )); do
			echo -e -n "  "
		done
	else
		for (( c=0; c<$PADDING; c++ )); do
			echo -e -n "\033[1C" 
		done
	fi
	
	if [ $NEWLINE = YES ]; then
		echo -e ${COLOR}"$MSG"${RESET_TXT}
	else
		echo -e -n ${COLOR}"$MSG"${RESET_TXT}
	fi

}

function abort()
{
	print
	print -l 0 -c $RED_TXT -m "--- Update FAILED ---"
	cd $CALL_DIR
	exit 1
}

function parseArgs()
{
	POSITIONAL_ARGS=()
	
	while [[ $# -gt 0 ]]; do
		case $1 in
			-r|--recursive)
			  RECURSIVE=YES
			  shift # past argument
			  ;;
			--default)
			  DEFAULT=YES
			  shift # past argument
			  ;;
			-*|--*)
			  echo "Unknown option \"$1\""
			  return 1
			  ;;
			*)
			  POSITIONAL_ARGS+=("$1") # save positional arg
			  shift # past argument
			  ;;
		esac
	done
	
	if [ ${#POSITIONAL_ARGS[@]} -gt 0 ]; then
		START_DIR=${POSITIONAL_ARGS[0]}
	fi
}

function isRepo()
{
	RETURN_DIR=$PWD
	RESULT=0
	
	{
		cd $1
		RAW_RESULT=$(git rev-parse --is-inside-work-tree)
		RESULT=$(expr "$RAW_RESULT" == "true")
	} &>/dev/null
	
	cd $RETURN_DIR
	echo $RESULT
}

function printSubmoduleState()
{
	SM_DIR=$1
	
	if ! [ -d "$SM_DIR" ]; then
		print -p 18 -c $RED_TXT "<missing>"
		MISSING+=($SM_DIR)
		return
	fi	
	
	cd $SM_DIR
	branch=$(git branch --show-current)
	commit=$(git rev-parse --short HEAD)
	diff="$(git diff)"
	diff_staged="$(git diff --staged)"
	
	if ! [ -f ".git" ]; then
		print -p 18 -c $RED_TXT "<missing>"
		MISSING+=($SM_DIR)
		return
	fi		
	
	SM_NAME=${PWD##*/}
	cd ..
	sm_commit=$(git ls-tree HEAD $SM_NAME --abbrev=${#commit})
	arrIN=(${sm_commit// / })
	sm_commit=${arrIN[2]}
	cd $START_DIR/$SM_DIR
	commit_delta=$(git rev-list --left-right --count $sm_commit...$commit)
	arrIN=(${commit_delta// / })
	commits_behind=${arrIN[0]}
	commits_ahead=${arrIN[1]}
	
	col_spacing=3

	if [ "$diff" != "" ] || [ "$diff_staged" != "" ]; then
		print -p 0 -c $RED_TXT -m "dirty" -n
		DIRTY+=($SM_DIR)
	else
		print -p 0 -c $GRAY_TXT -m "clean" -n
	fi
	
	print -p $col_spacing -n

	if [ $commits_behind -gt 0 ] || [ $commits_ahead -gt 0 ]; then
		paddingLeft=$((3 - ${#commits_behind}))
		paddingRight=$((3 - ${#commits_ahead}))
		print -p $paddingLeft -c $RED_TXT -m "${commits_behind}" -n
		print -p 0 -c $RED_TXT -m "|" -n
		print -p 0 -c $RED_TXT -m "${commits_ahead}" -n
		print -p $paddingRight -n
		DESYNCD+=($SM_DIR)
	else
		print -p 0 -c $GRAY_TXT -m "  0|0  " -n
	fi
	
	print -p $col_spacing -n
	
	if [ "$branch" = "" ]; then
		print -p 0 -c $YELLOW_TXT -m "$commit (detached)" -n
		DETACHED+=($SM_DIR)
	else
		print -p 0 -c $GREEN_TXT -m "$branch" -n
	fi
	
	print
	cd $START_DIR
}

function printConfigState()
{	
	REPO_DIR=$PWD
	repo=$(git config --get remote.origin.url)
	branch=$(git branch --show-current)
	commit=$(git rev-parse --short HEAD)
	delta=$(git rev-list --left-right --count origin/$branch...$commit)
	arrIN=(${delta// / })
	commits_behind=${arrIN[0]}
	commits_ahead=${arrIN[1]}
	
	print "Origin: $repo"
	print "Branch: $branch ($commit)" -n
	
	if [ $commits_behind -gt 0 ] || [ $commits_ahead -gt 0 ]; then
		print -p 1 -c $RED_TXT -m "(${commits_behind}|${commits_ahead} origin)"
	else
		print
	fi
	
	print
	
	if [ -f .gitmodules ]; then
		if [ -s .gitmodules ]; then
			SUBMODULES=$(git config --file .gitmodules --get-regexp path | awk '{ print $2 }')
		fi
	fi
	
	MAX_DIR_LENGTH=0
	STAT_SPACING=5
	
	print "Submodules:"
	if [ ! -z "$SUBMODULES" ]; then
		for DIR in $SUBMODULES; do		
			if [ ${#DIR} -gt $MAX_DIR_LENGTH ]; then
				MAX_DIR_LENGTH=${#DIR}
			fi
		done
								
		for DIR in $SUBMODULES; do							
			DIR_LENGTH=${#DIR}
			STAT_OFFSET=$(( (MAX_DIR_LENGTH-DIR_LENGTH)+STAT_SPACING ))
			
			print -l 2 -m $DIR -n
			print -p $STAT_OFFSET -n
			printSubmoduleState $DIR
		done
	fi
}

function printOptions()
{
	print "What would you like to do?"
	print -l 2 "1. Pull from origin"
	print -l 2 "2. Commit changes on ${RED_TXT}dirty${RESET_TXT} submodules (${#DIRTY[@]})"
	print -l 2 "3. Sync ${RED_TXT}desync${RESET_TXT}'d submodules (${#DESYNCD[@]})"
	print -l 2 "4. Init ${RED_TXT}missing${RESET_TXT} submodules (${#MISSING[@]})"
	print -l 2 "5. Pull ${YELLOW_TXT}detached${RESET_TXT} submodules (${#DETACHED[@]})"
	print -l 2 "6. Refresh (default)"
	print -l 2 "7. Exit"
	print
	print "Selection: " -n
	read selection
	print
	
	case $selection in
		2)
			commitDirty
			;;
		3)
			reSync
			;;
		4)
			initMissing
			;;
		5)
			pullDetached
			;;
		7)
			exit
			;;
		*)
			script=$(readlink -f "$0")
			exec "$script"
			;;
	esac
	
	print
	print "Press any key to continue..." -n
	read
	
	cd $START_DIR
	script=$(readlink -f "$0")
	exec "$script"
}

function commitDirty()
{
	if [ ${#DIRTY[@]} -eq 0 ]; then
		print -c $RED_TXT -m "No dirty submodules"
		return
	fi
	
	print -m "Stepping through dirty submodules..."
	
	for DIR in ${DIRTY[@]}; do
		print -l 2 $DIR...
		
		print -l 3 "Would you like to use git cola (c), terminal (t), or skip (s) ? " -n
		read selection
		print
		
		case $selection in
			c)
				git cola -r $START_DIR/$DIR
				;;
		esac
	done
}

function initMissing()
{
	if [ ${#MISSING[@]} -eq 0 ]; then
		print -c $RED_TXT -m "No missing submodules"
		return
	fi
	
	print -m "Initialising submodules ${GRAY_TXT}(git submodule update --init --recursive)..."
	
	for DIR in ${MISSING[@]}; do
		print -l 2 $DIR... -n
		lasterror=0
		
		{
			git submodule update --init --recursive $DIR
			lasterror=$?
		} &>/dev/null
		
		if [ $lasterror -eq 0 ]; then
			print -p 1 -c $GREEN_TXT -m "DONE"
		else
			print -p 1 -c $RED_TXT -m "FAILED"
		fi
	done
}

function reSync()
{
	if [ ${#DESYNCD[@]} -eq 0 ]; then
		print -c $RED_TXT -m "No desync'd submodules"
		return
	fi
	
	for DIR in ${DESYNCD[@]}; do	
		print -l 2 -m $DIR... -n
		lasterror=0
		
		{
			git submodule update --recursive $DIR
			lasterror=$?
		} &>/dev/null
		
		if [ $lasterror -eq 0 ]; then
			print -p 1 -c $GREEN_TXT -m "DONE"
		else
			print -p 1 -c $RED_TXT -m "FAILED"
		fi
	done
	
	cd $START_DIR
}

function pullDetached()
{
	if [ ${#DETACHED[@]} -eq 0 ]; then
		print -c $RED_TXT -m "No detached submodules"
		return
	fi
	
	print -m "Pulling detached submodules ${GRAY_TXT}(git checkout + git pull)..."
	
	for DIR in ${DETACHED[@]}; do		
		print -l 2 -m $DIR -n
		
		lasterror=0
		
		{
			git remote update
			lasterror=$?
		} &>/dev/null
		
		if [ $lasterror -ne 0 ]; then
			print -p 1 -c $RED_TXT -m "FAILED"
			continue
		fi		
	
		cd $START_DIR/$DIR
		commit=$(git rev-parse --short HEAD)		
		branches=$(git show-ref --head | grep ${commit})		
		lines=$(echo -e -n $branches | wc -l)
		branch=$commit
		
		print -p 3 -c $YELLOW_TXT -m $commit -n
		
		#print #debug
		
		# Try to find branch with the commit as the head
		count=0
		while IFS= read -r line; do
						
			if [[ $line == *HEAD ]]; then
				continue
			fi
			
			#print -c $BLUE_TXT -m "$line" #debug	
			
			arrIN=(${line//\// })
			parts=${#arrIN[@]}
			branch=${arrIN[parts-1]}
			
			#print -c $BLUE_TXT -m "$branch" #debug
			
		done <<< $branches
		
		lasterror=0
		#print -c $BLUE_TXT -m "$branch" #debug
		
		{
			git checkout $branch
			
			if [ $branch != $commit ]; then
				git pull
			fi
			lasterror=$?
		} &>/dev/null
		
		if [ $lasterror -eq 0 ]; then
			if [ $branch = $commit ]; then
				print -p 1 -c $RED_TXT -m "[no HEAD]"
			else
				print -p 1 -c $GREEN_TXT -m "$branch"
			fi
		else
			print -p 1 -c $RED_TXT -m "FAILED"
		fi		
	done
	
	cd $START_DIR
}

clear
print -l 0 -c $BLUE_TXT -m "--- Update submodules ---"
print

parseArgs $@

print "START_DIR: $START_DIR"
print "RECURSIVE: $RECURSIVE"

{
	git submodule sync --recursive
} &>/dev/null

cd $START_DIR
IS_REPO=$(isRepo $PWD)

if [ $IS_REPO = 0 ] && [ $RECURSIVE = NO ]; then
	print -c $RED_TXT "START_DIR is not a repo and recursive option not used"
	abort
fi

print
if [ $IS_REPO = 1 ]; then
	printConfigState
	print
	printOptions
fi


print
print -l 0 -c $GREEN_TXT -m "--- Update SUCCESSFUL ---"

# Return to directory the script was called from
cd $CALL_DIR
