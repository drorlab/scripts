#!/bin/bash
# Cancel all jobs with name in job description.
if [ "$#" -ne 1 ]
then
    echo "Usage: scripts/run-cancel.sh PATTERN"
    exit
fi
squeue -u $USER -o "%50j %50i"  | grep $1 | tr -s ' ' | cut -d " " -f 2 | xargs scancel
