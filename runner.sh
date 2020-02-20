#!/bin/bash -x 
cd `dirname $0`
inotifywait > /dev/null 2>&1
if [ $? == 127 ] ; then
echo "sudo apt install inotify-tools"
exit 1
fi 
PID=/var/run/lock/runner.pid
WATCH=$1
if [ -z $WATCH ] ; then
echo "$WATCH doesn't exist"
exit 1
fi

shift
pwd 
let err=0
while [[ 1 ]]; do 
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
$@ &

if [ $? != 0 ] ; then
  echo "command failed"
  exit 1
fi
done
