#!/bin/bash
# while true; do
#   import_task_status_command="aws --profile default ec2 wait instance-status-ok --region us-east-2 --instance-ids i-039e3007429513cb8"
#   echo "Running command: ${import_task_status_command}"
#   import_task_status=$(${import_task_status_command})
#   echo "Import task [${import_task_id}] status is [${import_task_status}]."

#   if [[ "$import_task_status" == "" ]]; then
#     echo "Completed, exiting..."
#     break
#   elif [[ "$import_task_status" == "active" ]]; then
#     echo "Waiting 1 minute..."
#     sleep 60
#   else
#     echo "Error, exiting..."
#     exit 1
#   fi
# done

while true ; do 
  echo "WAIT FOR: Jenkins is fully up and running"
  result=$(curl -s localhost:8080 | grep -nE "Authentication required")
  if [ -n "$result" ] ; then
    echo "COMPLETE! Jenkins is up and running!"
    break
  fi
  ((c++)) && ((c==2)) && break
  sleep 3
done