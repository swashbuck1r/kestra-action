#!/bin/bash

set +x

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
outputs="$CLOUDBEES_OUTPUTS"

mkdir -p "$outputs"
cd "$workspace" || exit

# Upload the flow
curl --silent -X POST --upload-file "$flow_name.yaml" -H "content-type: application/x-yaml" "http://localhost:8080/api/v1/flows" > upload.json  || exit
curl --silent -X PUT --upload-file "$flow_name.yaml" -H "content-type: application/x-yaml" "http://localhost:8080/api/v1/flows/$namespace/$flow_name" > upload.json || exit
cat upload.json

# Execute the flow
curl --silent -X POST -H "Content-Type: multipart/form-data" "http://localhost:8080/api/v1/executions/$namespace/$flow_name" > execution.json || exit
cat execution.json
execution_id=$(cat execution.json | jq -r '.id')

# Watch the flow
curl --silent "http://localhost:8080/api/v1/executions/$execution_id/follow" || exit

# Watch the logs
curl --silent "http://localhost:8080/api/v1/logs/$execution_id" > logs.json || exit
cat logs.json | jq -r '. | map("[\(.taskId)] \(.message)")'


# curl --silent "http://localhost:8080/api/v1/logs/$execution_id/download" > logs.txt
# cat logs.txt

# Grab the final result
curl --silent "http://localhost:8080/api/v1/executions/$execution_id" | jq > result.json || exit

json_data=$(cat result.json)

# Loop through output keys
for key in $(echo "$json_data" | jq -r '.outputs | keys[]'); do
    # Access the value for the current key
    value=$(echo "$json_data" | jq -r ".outputs[\"$key\"]")

    # Store the kestra output as a cloudbees step output
    echo "$value" > "$outputs/$key"
done

echo "$json_data" | jq -r '.outputs' > "$outputs/flow_outputs"
echo "$json_data" | jq -r '.state.current' > "$outputs/flow_state"
echo "$json_data" | jq > "$outputs/flow_execution"