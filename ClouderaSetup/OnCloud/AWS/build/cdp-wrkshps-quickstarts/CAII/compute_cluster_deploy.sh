#!/bin/bash

# Input: workshop name
workshop_name=$1
env_name="${workshop_name}-cdp-env"
cluster_name="${workshop_name}-compute-cluster"

# Get the status of the default cluster
default_cluster_status=$(cdp compute list-clusters | jq -r --arg env_name "$env_name" '
  .clusters[]
  | select(.isDefault == true and .envName == $env_name)
  | .status
')

# Get the status of the target compute cluster
existing_cluster_status=$(cdp compute list-clusters | jq -r --arg name "$cluster_name" '
  .clusters[]
  | select(.clusterName == $name)
  | .status
')

# Main logic
if [[ "$default_cluster_status" == "RUNNING" || "$default_cluster_status" == "CREATING" ]]; then
  echo "✅ Default compute cluster is in '$default_cluster_status' state."

  if [[ "$existing_cluster_status" == "RUNNING" ]]; then
    echo "✅ Compute cluster '$cluster_name' is already RUNNING. Skipping creation."

  elif [[ "$existing_cluster_status" == "CREATING" ]]; then
    echo "ℹ️ Compute cluster '$cluster_name' is in CREATING state. Skipping creation."

  else
    echo "🚀 Creating compute cluster: $cluster_name"
    cdp compute create-cluster --environment "$env_name" --name "$cluster_name"
  fi

  # wait until the cluster is RUNNING
  echo "⏳ Waiting for cluster '$cluster_name' to reach RUNNING state..."
  while true; do
    current_status=$(cdp compute list-clusters | jq -r --arg name "$cluster_name" '
      .clusters[] | select(.clusterName == $name) | .status')

    if [[ "$current_status" == "RUNNING" ]]; then
      echo "✅ Cluster '$cluster_name' is now RUNNING."
      break
    elif [[ "$current_status" == "FAILED" ]]; then
      echo "❌ Cluster creation FAILED."
      exit 1
    else
      echo "⏳ Current status: $current_status. Retrying in 30 seconds..."
      sleep 30
    fi
  done

else
  echo "❌ Default compute cluster is not in a suitable state (RUNNING/CREATING). Cannot proceed."
  exit 1
fi
