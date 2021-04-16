#!/bin/bash 
#cd `dirname $0`

echo "my pid is $$"

while IFS=';' read -ra here; do
        WATCH+="${here[@]} "
done 
echo "${#WATCH[@]}"        # print array length
echo "${WATCH[@]}"         # print array elements
#for file in "${WATCH[@]}"; do echo "$file"; done  # loop over the array

PROG=inotifywait
LOCK_DIR=/var/run/lock/

if [ ! -d $LOCK_DIR ] ; then
LOCK_DIR=$TMP
fi 

PIDF=${LOCK_DIR}/runner.pid


$PROG > /dev/null 2>&1

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

touch $PIDF


trap "pkill -HUP ${PROG}" SIGHUP
trap "pkill -ABRT ${PROG}" SIGABRT

let err=0
while [[ 1 ]]; do 
pwd 

echo "$@ is waiting"
${PROG} ${ARGS} $WATCH &

PID=$!
echo $PID
echo -n $PID > ${LOCK_DIR}/runner.pid

echo "checking up to date"
for file in $WATCH ;  do
  if [ $file -nt $PIDF ] ; then
    echo "building newer"
    touch PID
    $@ 
    break
  fi
done  


wait $PID


RET=$?
echo "prog exited $RET"

if [ $RET -eq 129 ] ; then
  echo "normal continue"
  continue;
elif [ $RET -eq 134 ] ; then
  echo "abort"
elif [ "$RET" -gt 1 ] ; then
  echo "watch failed"
  exit 1
fi

sleep 1

#if [ -f $PIDF ] ; then
#fi
#TODO 
#$@ &
touch $PIDF
$@ &
PID=$!
echo "RUNNING $@ $PID"
echo -n $PID > $LOCK_DIR/runner.pid
wait $PID 
RET=$?
echo "completed"

if [ "$RET" != 0 ] ; then
  echo "command failed"
  #exit 1
fi
done
