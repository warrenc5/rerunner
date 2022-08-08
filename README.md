# re-runner
Use inotify to watch a file and run a command when it changes

Simple rerun target.sh when you save it

```
usage runner.sh target.sh [args]
```

Send a list of files to monitor on stdin

```
usage runner.sh target.sh [args] <<<`find . -name \*.java -o -name \*.js -o -name \*.xml | grep -v "test\|target"`
```

Use a here document to specify the file list

```
usage runner.sh target.sh <<EOF some list of files EOF
```

Can send traps through to the target.sh e.g CTRL-C CTRL-X
