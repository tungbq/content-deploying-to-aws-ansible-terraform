#!/bin/bash

MAX_RETRIES=3
RETRIES=0

while [[ $RETRIES -lt $MAX_RETRIES ]]; do
  import_task_status_command="aws --profile $1 ec2 wait instance-status-ok --region $2 --instance-ids $3"
  echo "Running command: $import_task_status_command"
  import_task_status=$(${import_task_status_command} 2>&1)
  echo "Status is [${import_task_status}]."

  if [[ "$import_task_status" == "" ]]; then
    echo "Completed, exiting..."
    break
  elif [[ "$import_task_status" == *"Max attempts exceeded"* ]]; then
    RETRIES=$((RETRIES+1))
    echo "Time out, waiting 1 minute..."
    sleep 60
  else
    echo "Error, exiting..."
    exit 1
  fi
done

if [[ $RETRIES -eq $MAX_RETRIES ]]; then
  echo "Command failed after $MAX_RETRIES retries"
fi
