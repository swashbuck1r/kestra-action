#!/bin/bash

if [[ "$DEBUG" = "true" ]]; then
  set -x
fi

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

if [[ -z "${PARAMETERS_JSON}" ]]; then
  PARAMETERS_JSON='{}'
fi

curl_args=""
if [[ "$DEBUG" = "true" ]]; then
  curl_args=""
else
  curl_args="--silent"
fi

namespace="$1"
flow_name="$2"
workspace="$CLOUDBEES_WORKSPACE"
outputs="$CLOUDBEES_OUTPUTS"

mkdir -p "$outputs"

# Test if the flow exists, if so delete it
curl $curl_args --fail "http://localhost:8080/api/v1/flows/$namespace/$flow_name" > /dev/null
exit_code=$?
if [[ $exit_code -eq 0 ]]; then
  curl $curl_args -X DELETE "http://localhost:8080/api/v1/flows/$namespace/$flow_name" || exit
fi
# Upload the flow
curl $curl_args -X POST --upload-file "$workspace/$flow_name.yaml" -H "content-type: application/x-yaml" "http://localhost:8080/api/v1/flows" > upload.json  || exit

# verify the flow was created
curl $curl_args --fail "http://localhost:8080/api/v1/flows/$namespace/$flow_name" > /dev/null
exit_code=$?
if [[ $exit_code -ne 0 ]]; then
  cat upload.json | jq
  >&2 echo "Failed to upload flow"
  exit 1
fi

if [[ "$DEBUG" = "true" ]]; then
  cat upload.json | jq
fi
# Execute the flow
input_json="$PARAMETERS_JSON"
if [[ "$DEBUG" = "true" ]]; then
  echo "--- input_json ---"
  echo "$input_json" | jq
fi
curl_cmd="curl $curl_args -X POST -H \"Content-Type: multipart/form-data\""
# Loop through input keys
for key in $(echo "$input_json" | jq -r '. | keys[]'); do
    # Access the value for the current key
    value=$(echo "$input_json" | jq -r ".[\"$key\"]")

    # add the input to the curl command
    curl_cmd="$curl_cmd --data-urlencode \"$key=$value\""
done
curl_cmd="$curl_cmd http://localhost:8080/api/v1/executions/$namespace/$flow_name"
eval "$curl_cmd" > execution.json || exit
if [[ "$DEBUG" = "true" ]]; then
  echo "--- execution details ---"
  cat "execution.json" | jq
fi

execution_id=$(cat "execution.json" | jq -r '.id')

# stream the logs
echo ""
echo "--- [$namespace/$flow_name] flow logs ---"
./stream-logs.sh "$execution_id" &

# Watch the flow
curl $curl_args "http://localhost:8080/api/v1/executions/$execution_id/follow" > exec_follow.log || exit


# Grab the final result
curl $curl_args "http://localhost:8080/api/v1/executions/$execution_id" | jq > result.json || exit
json_data=$(cat result.json)
if [[ "$DEBUG" = "true" ]]; then
  echo "--- execution results ---"
  cat "result.json" | jq
fi

# Transfer the kestra flow outputs to cloudbees outputs
for key in $(echo "$json_data" | jq -r '.outputs | keys[]'); do
    value=$(echo "$json_data" | jq -r ".outputs[\"$key\"]")
    echo "$value" > "$outputs/$key"
done

echo "$json_data" | jq -r '.outputs' > "$outputs/flow_outputs"
echo "$json_data" | jq -r '.state.current' > "$outputs/flow_state"
echo "$json_data" | jq > "$outputs/flow_execution"