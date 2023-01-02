#!/bin/bash

# Useful variables
RED_TXT='\033[0;31m'
GREEN_TXT='\033[0;32m'
GRAY_TXT='\033[1;30m'
BLUE_TXT='\033[0;34m'
YELLOW_TXT='\033[0;33m'
RESET_TXT='\033[0m'
POSITIONAL_ARGS=()
EXIT_CODE=0
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
DISK_PATH="/dev/disk/by-label/RPI-RP2"
MOUNT_PATH="/media/$USER/RPI-RP2"
PROG=""

function parseArgs()
{
	while [[ $# -gt 0 ]]; do
	  case $1 in
		-b|--build-path)
		  BUILD_PATH="$2"
		  shift # past argument
		  shift # past value
		  ;;
		-d|--dev_path)
		  DEV_PATH="$2"
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

	set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters
}

function resetPico()
{
	echo -e "Resetting Pico into storage mode..."
	${SCRIPT_DIR}/picotool/build/picotool reboot -u -f
	sleep 5
}

function findPico()
{
	echo -e "Looking for Pico..."
	
	if [ -e ${DEV_PATH} ]; then
		echo -e ${GREEN_TXT}"Pico is running."${RESET_TXT}
		resetPico
	fi
		
	if [ -e ${DISK_PATH} ]; then
		echo -e ${GREEN_TXT}"Pico is in storage mode."${RESET_TXT}
	
		if [ ! -d ${MOUNT_PATH} ]; then
			echo -e "Mounting Pico..."
			udisksctl mount --block-device ${DISK_PATH}
			
			if [ ! -d ${MOUNT_PATH} ]; then
				echo -e ${RED_TXT}"Failed to mount Pico."${RESET_TXT}
				abort
			fi
		fi
		
		echo -e ${GREEN_TXT}"Pico is mounted."${RESET_TXT}
	else
		echo -e ${RED_TXT}"Cannot find Pico."${RESET_TXT}
		abort
	fi
}

function findProgram()
{
	echo -e "Looking for Program..."
	FILES=()
	
	if [ -d ${BUILD_PATH} ]; then
		FILES=$(find ${BUILD_PATH} -type f -name "*.uf2")
	else
		echo -e ${RED_TXT}"Build path not found."${RESET_TXT}
		abort
	fi
	
	if [ -z "${FILES[0]}" ]; then
		echo -e ${RED_TXT}"Cannot find .uf2 file."${RESET_TXT}
		abort
	else
		PROG="$(basename -- ${FILES[0]})"
		echo -e ${GREEN_TXT}"Found ${PROG}"${RESET_TXT}
	fi
}

function deployProgram()
{
	echo -e "Deploying Program..."
	if cp ${BUILD_PATH}/${PROG} ${MOUNT_PATH}; then
		echo -e ${GREEN_TXT}"Success."${RESET_TXT}
	else
		echo -e ${RED_TXT}"Failed."${RESET_TXT}
		abort
	fi
}

function abort()
{
	echo -e ""
	echo -e ${BLUE_TXT}"===================="${RESET_TXT}
	exit 1
}

echo -e ${BLUE_TXT}"=== Deploy 2 Pico ==="${RESET_TXT}
echo -e ""

parseArgs $@
echo -e "Build path:\t${BUILD_PATH}"
echo -e "Pico dev path:\t${DEV_PATH}"
echo -e ""

findPico
echo -e ""

findProgram
echo -e ""

deployProgram

echo -e ""
echo -e ${BLUE_TXT}"===================="${RESET_TXT}
exit 0

