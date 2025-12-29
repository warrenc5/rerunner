#!/bin/bash 
#set -x
#cd `dirname $0`

CONT=(0 123 124 131) #xargs runner will continue
EXIT=(1 126 127) #xargs - runner will exit

MY_PID=$$
DRY_RUN=${DRY:-}
VERBOSE=1
xpatterns=("\.sw.*" "\.netbeans_automatic_build")

RED="\e[31m"
BOLD="\e[1m"
GREEN="\e[32m"
BLUE="\e[34m"
RESET="\e[0m"
CYAN="\e[36m"
MAGENTA="\e[35m"
YELLOW="\e[33m"
WHITE="\e[97m"
BLACK="\e[30m"
ITALICS="\e[3m"
UNDERLINE="\e[4m"
RESET="\e[0m"
BOLD="\e[1m"
ITALICS="\e[3m"
UNDERLINE="\e[4m"
RED="\e[31m"
GREEN="\e[32m"
ORANGE="\e[33m"
BLUE="\e[34m"
CYAN="\e[36m"
MAGENTA="\e[35m"
YELLOW="\e[33m"
WHITE="\e[97m"
BLACK="\e[30m"

DATE="date --rfc-3339=seconds"
DATE2="date +%Y%m%d%H%M%S"

echo -e $RESET
echo "my pid is $MY_PID"
[[ $VERBOSE -eq 1 && ${DRY_RUN} -ne "" ]] && echo -e "${YELLOW}==============DRY_RUN============${RESET}" 

MAX=200
PROG=$@ #Program to run with arguments
PROG_CUT=${PROG[@]}
PROG_CUT=${PROG_CUT:0:200}
echo -e ${WHITE}${PROG_CUT}${RESET}

if [ -z "$1" ] ; then 
echo 'traps are CTRL+\ to rerun, CTRL+C to int, CTRL+Z hup exit'
echo 'during program run traps CTRL+\ CTRL+C are passed through, CTRL+Z hup exit'
echo 'usage runner.sh target.sh // by default it will watch target.sh'
echo 'usage runner.sh target.sh <<<`find . -name \*.java -o -name \*.js -o -name \*.xml | grep -v "test\|target"`'
echo 'usage runner.sh target.sh <<<$(ls this file and that file)'
echo "usage runner.sh target.sh <<EOF some list of files separated by IFS or new lines\nEOF"
exit 1
fi

unset input
unset WATCH

declare -a my_array
WATCH=()

if [ ! -f "$1" ] ; then 
echo "$1 not found" && exit 1 
fi


while IFS=';' read -t 1 -ra input && [ -n "$input" ]; do 
  #echo watching $input
  WATCH+=(${input[@]})
done

filtered=()

for item in "${WATCH[@]}"; do
  m=0
  for pat in "${xpatterns[@]}"; do
    if [[ $item =~ $pat ]]; then
        [[ $VERBOSE -eq 1 ]] && echo "remove: $item $pat"
        m=1
        break;
    fi
  done

  [[ $m -eq 0 ]] && [[ -f $item ]] && filtered+=($item) 

done

WATCH=("${filtered[@]}")

if [[ 0 -eq ${#WATCH[@]} ]] ; then 
  echo 'default - watching target'
  for arg in $@ ; do
    r=`realpath $arg`
    WATCH+=($r)
  done

  #[[ $VERBOSE -eq 1 ]] && echo -e "${ITALICS}input ${WATCH[@]}${RESET}"         # print array elements
fi 

WATCH_CUT=${WATCH[@]}
WATCH_CUT=${WATCH_CUT:0:200}

echo "watching ${#WATCH[@]} files"        # print array length

echo -e "${ITALICS}watching filtered ${WATCH_CUT}${RESET}"         # print array elements
#[[ $VERBOSE -eq 1 ]] && echo -e "${ITALICS}watching filtered ${WATCH[@]}${RESET}"         # print array elements

LOCK_DIR=/var/run/lock/

if [ ! -d $LOCK_DIR ] ; then
  LOCK_DIR=$TMP
fi

PIDF=${LOCK_DIR}/runner.pid
#echo $MY_PID > ${PIDF}
echo ${MY_PID} ${PIDF}

IPROG=inotifywait 
which $IPROG > /dev/null 2>&1

#ARGS="-o /tmp/inotify-${MY_PID} -d -r -"

EVENTS=(modify attrib create)

for event in "${EVENTS[@]}"; do 
  ARGS="$ARGS -e ${event}"
done  

if [ $? -ne 0 ] ; then # fallback to fswatch
  IPROG=fswatch
  ARGS="-1 -l 1 "
fi

XARGS="xargs ${IPROG} ${ARGS}"
#[[ $VERBOSE -eq 1 ]] XARGS="xargs -t ${IPROG} ${ARGS}"

if [ $? == 127 ] ; then
  echo "sudo apt install inotify-tools"
  echo "sudo brew install fswatch"
  exit 1
fi

echo $IPROG

if [ -z "$1" ] ; then
echo "usage runner.sh target.sh <<<`find . -name \*.java -o -name \*.js -o -name \*.xml | grep -v "test\|target"`"
echo "usage runner.sh target.sh <<EOF some list of files EOF"
fi

DATE=`date -u +'%Y-%m-%dT%H:%M:%S'`
echo "starting with pid date ${DATE}"
#FIXME: traps 
#set -o ignoreeof
#CTRL+\

let err=0

function update() { 
touch -d ${DATE} ${PIDF}
}

function traps() { 
set +x
  trap "echo -e \"${WHITE}${BOLD}trap quit${RESET}\" && update && kill -HUP ${PID}" QUIT #CTRL-\
  trap "echo -e \"${WHITE}${BOLD}trap exit${RESET}\" && kill -HUP ${PID} ; kill -- $$" EXIT 
  trap "echo -e \"${WHITE}${BOLD}trap hup${RESET}\" && kill -HUP ${PID}" SIGHUP #129
  trap "echo -e \"${WHITE}${BOLD}trap abort'${RESET}\" && kill -ABRT ${PID}" SIGABRT
  trap "echo -e \"${WHITE}${BOLD}trap int${RESET}\" && kill -HUP ${MY_PID}" INT #CTRL-C #130
  trap "echo -e \"${WHITE}${BOLD}trap stop${RESET}\" && kill -HUP ${MY_PID}" TSTP #CTRL-Z
}

traps

function run () { 
  touch $PIDF
  echo "------------------------>" 

  if [[ -z $DRY_RUN ]] ; then 
    ${PROG} &
  else 
    [[ $VERBOSE -eq 1 ]] && echo -e ${YELLOW}${PROG_CUT}${RESET} 
    sleep 10
  fi 
  
  PID=$!
  #send signals to prog
  trap "echo -e \"${WHITE}${UNDERLINE}trap int ${PROG}${RESET}\" && traps && kill -TERM ${PID}" INT #CTRL-C
  trap "echo -e \"${WHITE}${UNDERLINE}trap quit${RESET}\" && traps && kill -QUIT ${PID}" QUIT #CTRL-\
  trap "echo -e \"${WHITE}${UNDERLINE}trap stop${RESET}\" && traps && kill -TERM ${PID}" TSTP #CTRL-Z

  #echo "RUNNING ${PROG} $PID `date -Iseconds`" 
  echo -e "${WHITE}${UNDERLINE}RUNNING${UNDERLINE} '${PROG}' ${ITALICS}pid: $PID time: `date -u +'%Y-%m-%dT%H:%M:%S'` ${RESET}"
  echo -n $PID > $LOCK_DIR/runner-cmd.pid
  wait $PID 
  RET=$?
  traps

  echo "<------------------------"

  if [ $RET -eq 0 ] ; then
    echo -e ${GREEN}${BOLD}${PROG} $PID - completed - return code:${ITALICS} ${RET}${RESET}
  elif (( $RET > 128 )); then 
    sig=$(($RET-128)); 
    echo -e ${WHITE}${BOLD}${PROG} $PID was KILLED $sig $(kill -l $sig) ${RESET} 
    if [[ $sig -eq 20 ]] ; then
      kill -HUP ${PID}
    fi

  else 
    echo -e ${RED}${BOLD}${PROG} $PID - command failed - return code:${ITALICS} ${RET}${RESET}
  fi

}

while [[ 1 ]]; do
  pwd

  echo "checking up to date"

  traps

  for file in ${WATCH[@]};  do
    if [ $file -nt $PIDF ] ; then
      echo -e ${YELLOW}building newer $file${RESET}
      run
      break
    fi
  done  

  #set -x

  echo -e "${PROG_CUT} ${WHITE}${ITALICS}is waiting for notification to run${RESET}"
  echo -e "using ${ITALICS}${IPROG} ${ARGS}${RESET}"
  set +x

  if [[ $VERBOSE -eq 1 ]] ; then
    echo ${WATCH[@]} | $XARGS &
  else 
    echo ${WATCH[@]} | $XAGRS &
  fi 

  PID=$!
  traps 
  sleep 1
  [[ $VERBOSE -eq 1 ]] && echo -e ${ITALICS}watcher pid: $PID${RESET}
  set -x
  wait $PID
  RET=$?

  echo "${IPROG} exited $RET"

  #XARGS exited

  if [[ " ${CONT[*]} " =~ " $RET " ]] ; then  
    echo -e ${GREEN}${UNDERLINE}$IPROG success exit with $RET ${RESET}
    run
  elif (( $RET > 128 )); then 
    sig=$(($RET-128)); 
    echo -e ${WHITE}${BOLD}${IPROG} was KILLED $sig $(kill -l $sig) ${RESET} 
    kill $SIG ${MY_PID}
  elif [[ " ${EXIT[*]} " =~ " $RET " ]] ; then 
    echo -e ${RED}${UNDERLINE}$IPROG failed exit with ${RET} ${RESET}
    exit $RET
  else
    echo -e ${RED}${UNDERLINE}$IPROG failed with $RET - valid are ${EXIT[*]} and ${CONT[*]} ${RESET}
    exit 69
  fi
done
