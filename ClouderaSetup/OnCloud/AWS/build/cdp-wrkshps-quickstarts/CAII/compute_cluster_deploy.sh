#!/bin/bash

# Input: workshop name
workshop_name=$1
env_name="${workshop_name}-cdp-env"
cluster_name="${workshop_name}-compute-cluster"

# Get the status of the default compute cluster
default_cluster_status=$(cdp compute list-clusters | jq -r --arg env_name "$env_name" '
  .clusters[]
  | select(.isDefault == true and .envName == $env_name)
  | .status
')

# Initialize default compute cluster if not in RUNNING or CREATING state
if [[ "$default_cluster_status" != "RUNNING" && "$default_cluster_status" != "CREATING" ]]; then
  echo "⚙️ Initializing default compute cluster for environment: $env_name"
  cdp environments initialize-aws-compute-cluster --cli-input-json file://updated-convert-v2-env.json

  # Wait for the default cluster to reach RUNNING state
  echo "⏳ Waiting for default compute cluster to reach RUNNING state..."
  while true; do
    default_cluster_status=$(cdp compute list-clusters | jq -r --arg env_name "$env_name" '
      .clusters[]
      | select(.isDefault == true and .envName == $env_name)
      | .status')

    if [[ "$default_cluster_status" == "RUNNING" ]]; then
      echo "✅ Default compute cluster is now RUNNING."
      break
    elif [[ "$default_cluster_status" == "FAILED" ]]; then
      echo "❌ Default compute cluster initialization FAILED."
      exit 1
    else
      echo "⏳ Default cluster status: $default_cluster_status. Retrying in 30 seconds..."
      sleep 30
    fi
  done
else
  echo "✅ Default compute cluster is in '$default_cluster_status' state."
fi

# Now proceed to create the compute cluster if needed
existing_cluster_status=$(cdp compute list-clusters | jq -r --arg name "$cluster_name" '
  .clusters[]
  | select(.clusterName == $name)
  | .status
')

if [[ "$existing_cluster_status" == "RUNNING" ]]; then
  echo "✅ Compute cluster '$cluster_name' is already RUNNING. Skipping creation."

elif [[ "$existing_cluster_status" == "CREATING" ]]; then
  echo "ℹ️ Compute cluster '$cluster_name' is already being created. Skipping creation."

else
  echo "🚀 Creating compute cluster: $cluster_name"
  cdp compute create-cluster --environment "$env_name" --name "$cluster_name"

  # Wait for the compute cluster to reach RUNNING state
  echo "⏳ Waiting for compute cluster '$cluster_name' to reach RUNNING state..."
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
fi
