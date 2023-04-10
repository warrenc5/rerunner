#!/bin/bash 
#set -x
#cd `dirname $0`
EXIT=${EXIT:-(123 0)}
CONT=(123 0 131 130)
EXIT=(137)
MY_PID=$$
echo "my pid is $MY_PID"
PROG=$@

if [ -z "$1" ] ; then 
echo 'traps are CTRL+\ to rerun and CTRL+C to int'
echo 'usage runner.sh target.sh // by default it will watch target.sh'
echo 'usage runner.sh target.sh <<<`find . -name \*.java -o -name \*.js -o -name \*.xml | grep -v "test\|target"`'
echo 'usage runner.sh target.sh <<<$(ls this file and that file)'
echo "usage runner.sh target.sh <<EOF some list of files separated by IFS or new lines\nEOF"
exit 1
fi

unset input
#while IFS=';' read -ra here; do
unset WATCH

while IFS=';' read -t 1 -ra input && [ -n "$input" ]; do 
  #echo watching $input
  WATCH+="${input[@]} "
done

if [ 0 -eq ${#WATCH[@]} ] ; then 
  #echo 'default watching target'
  WATCH+="$1"
fi 

echo "watching ${#WATCH[@]} files"        # print array length
echo "watching ${WATCH[@]}"         # print array elements
#for file in "${WATCH[@]}"; do echo "$file"; done  # loop over the array

IPROG=inotifywait 
# todo inotifywait

#ARGS="-o /tmp/inotify-${MY_PID} -d -r -"
ARGS="-e modify -e create"
LOCK_DIR=/var/run/lock/

if [ ! -d $LOCK_DIR ] ; then
  LOCK_DIR=$TMP
fi

PIDF=${LOCK_DIR}/runner.pid
#echo $MY_PID > ${PIDF}
echo ${MY_PID} ${PIDF}

which $IPROG > /dev/null 2>&1

if [ $? -ne 0 ] ; then
  IPROG=fswatch
  ARGS="-1 -l 1 "
fi

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

trap "echo 'quit1' && touch -d ${DATE} ${PIDF} && pkill -HUP ${IPROG}" QUIT
trap "echo 'exit1' && pkill -HUP ${IPROG}" EXIT
trap "echo 'hup' && pkill -HUP ${IPROG}" SIGHUP
trap "echo 'abort' && pkill -ABRT ${IPROG}" SIGABRT

let err=0

function run () { 
  touch $PIDF
  ${PROG} &
  PID=$!
  trap "echo 'int ${PROG}' && kill -9 ${PID}" INT
  #echo "RUNNING ${PROG} $PID `date -Iseconds`" 
  echo "RUNNING '${PROG}' pid: $PID time: `date -u +'%Y-%m-%dT%H:%M:%S'`"
  echo -n $PID > $LOCK_DIR/runner-cmd.pid
  wait $PID 
  RET=$?

  echo "completed"

  if [ "$RET" != 0 ] ; then
    echo "command failed"
  fi

}

while [[ 1 ]]; do
  pwd

  echo "checking up to date"

  trap "echo 'int2' && kill -9 ${MY_PID}" INT

  for file in $WATCH ;  do
    if [ $file -nt $PIDF ] ; then
      echo "building newer "
      run
      break
    fi
  done  

  #set -x

  echo "${PROG} is waiting for notification to run"
  echo ${IPROG} ${ARGS} 
  echo $WATCH | xargs ${IPROG} ${ARGS} &
  PID=$!
  echo $PID
  wait $PID
  RET=$?
  echo "${IPROG} exited $RET"

  if [[ " ${CONT[*]} " =~ " $RET " ]] ; then 
    echo $IPROG success exit with $RET 
    run
  elif [[ " ${EXIT[*]} " =~ " $RET " ]] ; then 
    echo $IPROG failed exit with $RET 
    exit $RET
  else
    echo $IPROG failed with $RET - valid are ${EXIT[*]} and ${CONT[*]}
    exit 69
  fi
done
