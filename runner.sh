#!/bin/bash 
#set -x
#cd `dirname $0`
EXIT=${EXIT:-(123 0)}
EXIT=(123 0)
MY_PID=$$
echo "my pid is $MY_PID"

if [ -z "$1" ] ; then 
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

PROG=inotifywait 
# todo inotifywait

#ARGS="-o /tmp/inotify-${MY_PID} -d -r -"
ARGS="-e modify -e create"
LOCK_DIR=/var/run/lock/

if [ ! -d $LOCK_DIR ] ; then
  LOCK_DIR=$TMP
fi

PIDF=${LOCK_DIR}/runner.pid

which $PROG > /dev/null 2>&1

if [ $? -ne 0 ] ; then
  PROG=fswatch
  ARGS="-1 -l 1 "
fi

if [ $? == 127 ] ; then
  echo "sudo apt install inotify-tools"
  echo "sudo brew install fswatch"
  exit 1
fi

echo $PROG

if [ -z "$1" ] ; then
echo "usage runner.sh target.sh <<<`find . -name \*.java -o -name \*.js -o -name \*.xml | grep -v "test\|target"`"
echo "usage runner.sh target.sh <<EOF some list of files EOF"
fi


trap "echo 'hup' && pkill -HUP ${PROG}" SIGHUP
trap "echo 'abort' && pkill -ABRT ${PROG}" SIGABRT
trap "echo 'int' && kill -9 `cat ${LOCK_DIR}/runner.pid`" INT

let err=0

while [[ 1 ]]; do
  pwd

  echo "checking up to date"

  for file in $WATCH ;  do
    if [ $file -nt $PIDF ] ; then
      echo "building newer"
      touch PID
      $@
      break
    fi
  done  

  touch $PIDF
  echo $$ > ${PIDF}

  #set -x

  echo "$@ is waiting for notification to run"
  echo ${PROG} ${ARGS} 

  echo $WATCH | xargs ${PROG} ${ARGS}

  RET=$?
  if [[ " ${EXIT[*]} " =~ " $RET " ]] ; then 
    echo $PROG success exit with $RET 
  else
    echo $PROG failed with $RET - valid are ${EXIT[*]}
    exit 69
  fi

  PID=$!
  echo $PID
  echo -n $PID > ${LOCK_DIR}/runner-cmd.pid

  trap "echo 'int' && kill -9 ${PID}" INT
  wait $PID

  RET=$?
  echo "${PROG} exited $RET"
  
  trap "echo 'int' && kill -9 `cat ${LOCK_DIR}/runner.pid`" INT
  sleep 1

  if [ $RET -eq 0 ] ; then
    echo "normal exit"
  elif [ $RET -eq 129 ] || [ $RET -eq 130 ] ; then
    echo "normal continue"
    continue;
  elif [ $RET -eq 134 ] ; then
    echo "abort"
  elif [ "$RET" -gt 1 ] ; then
    echo "watch failed"
    exit 1
  fi

  trap "echo 'int' && kill -9 `cat ${LOCK_DIR}/runner.pid`" INT

  sleep 1
  #if [ -f $PIDF ] ; then
  #fi
  #TODO
  #$@ &
  touch $PIDF
  $@ &
  PID=$!
  #echo "RUNNING $@ $PID `date -Iseconds`" 
  echo "RUNNING $@ $PID `date -u +'%Y-%m-%dT%H:%M:%S'`"
  echo -n $PID > $LOCK_DIR/runner-cmd.pid
  trap "echo 'int' && kill -9 ${PID}" INT
  wait $PID 
  RET=$?
  echo "completed"

  if [ "$RET" != 0 ] ; then
    echo "command failed"
    #exit 1
  fi
done
