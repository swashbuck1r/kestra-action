#!/bin/bash

set +x

if [[ -z "${1}" ]]; then
  echo "missing execution_id argument"
  exit 1
fi

execution_id="$1"

curl -sN "http://localhost:8080/api/v1/logs/$execution_id/follow" | while read line; do
  # Check for empty line (end of event)
  if [ -z "$line" ]; then
    continue
  fi

  # Parse the line based on the SSE format
  key="${line%%:*}"
  value="${line#*:}"

  case "$key" in
    "event")
      event="$value"
      ;;
    "data")
      data="$value"
      ;;
    "id")
      id="$value"
      ;;
    "retry")
      retry="$value"
      ;;
    *)
      echo "Unknown key: $key"
      ;;
  esac

  # Process the event data
  # if [ -n "$event" ]; then
  #   echo "Event: $event"
  # fi
  if [ -n "$data" ]; then
    message=$(echo "$data" | jq -r .message)
    echo "$message"
    data=""
  fi
  # if [ -n "$id" ]; then
  #   echo "ID: $id"
  # fi
  # if [ -n "$retry" ]; then
  #   echo "Retry: $retry"
  # fi
done

