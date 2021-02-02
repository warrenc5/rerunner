#!/bin/bash 
#cd `dirname $0`

while IFS=';' read -ra here; do
        WATCH+="${here[@]} "
done 
echo "${#WATCH[@]}"        # print array length
echo "${WATCH[@]}"         # print array elements
#for file in "${WATCH[@]}"; do echo "$file"; done  # loop over the array


inotifywait > /dev/null 2>&1
if [ -z "$1" ] ; then 
echo "usage runner.sh target.sh <<<`find . -name \*.java -o -name \*.js -o -name \*.xml | grep -v "test\|target"`"
echo "usage runner.sh target.sh <<EOF some list of files EOF"
fi 

if [ $? == 127 ] ; then
echo "sudo apt install inotify-tools"
exit 1
fi 

PIDF=/var/run/lock/runner.pid
touch $PIDF


trap "pkill -HUP inotifywait" SIGHUP
trap "pkill -ABRT inotifywait" SIGABRT

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

echo "$@ is waiting"
inotifywait -e modify $WATCH &

PID=$!
echo $PID
echo -n "$PID" > /var/run/lock/runner.pid
wait $PID
RET=$?
echo $RET

if [ $RET -eq 129 ] ; then
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
echo -n $PID > /var/run/lock/runner.pid
wait $PID 
RET=$?
echo "completed"

if [ "$RET" != 0 ] ; then
  echo "command failed"
  #exit 1
fi
done
