#!/bin/bash

set -x
namespace="company.team"
flow_name="myflow"

if [[ -z "${1}" ]]; then
  echo "missing namespace argument"
  exit 1
fi

if [[ -z "${2}" ]]; then
  echo "missing flow_name argument"
  exit 1
fi

if [[ -z "${CLOUDBEES_WORKSPACE}" ]]; then
  echo "CLOUDBEES_WORKSPACE must be set"
  exit 1
fi

if [[ -z "${CLOUDBEES_OUTPUTS}" ]]; then
  echo "CLOUDBEES_OUTPUTS must be set"
  exit 1
fi

namespace="$1"
flow_name="$2"
workspace="$CLOUDBEES_WORKSPACE"

/app/kestra server local > server.log &

# wait for the server to start

attempt_counter=0
max_attempts=5

until $(curl --output /dev/null --silent --head --fail http://localhost:8080); do
    if [ ${attempt_counter} -eq ${max_attempts} ];then
      echo "Max attempts reached"
      exit 1
    fi

    printf '.'
    attempt_counter=$(($attempt_counter+1))
    sleep 5
done

cd "$workspace" || exit
./upload-and-run.sh "$namespace" "$flow_name"

