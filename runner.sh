#!/bin/bash -x 
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

PID=/var/run/lock/runner.pid

let err=0
while [[ 1 ]]; do 
pwd 
inotifywait -e modify $WATCH
if [ $? != 1 ] ; then
  echo "watch failed"
  exit 1
fi
if [ -f $PID ] ; then
pid=`cat $PID` 
kill $pid
echo "killed $pid"
rm $PID
fi
#TODO 
#$@ &
$@ 
echo "completed"

if [ $? != 0 ] ; then
  echo "command failed"
  exit 1
fi
sleep 5
done
