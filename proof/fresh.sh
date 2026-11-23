#!/bin/sh
# usage: fresh.sh <url> <out>  — waits for the server, then runs the scenario into <out>
HERE=$(cd "$(dirname "$0")" && pwd)
for i in $(seq 1 60); do curl -s -o /dev/null "$1/api/v1.0/config/" && break; sleep 1; done
python3 "$HERE/drive.py" "$1" http://127.0.0.1:8600 > "$2" 2>&1
echo "exit $? steps $(grep -c '^###' "$2")"
grep '^###' "$2" | awk '{print $NF}' | sort | uniq -c
grep -- '-> 500' "$2"
