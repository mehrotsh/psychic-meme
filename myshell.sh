#!/bin/bash

# Usage: ./zk_control.sh <environment> <start|stop>

ENV=$1
ACTION=$2
TIMESTAMP=$(date +%Y%m%d%H%M%S)
LEADERINFO_FILE="leaderinfo_${ENV}_${TIMESTAMP}.txt"

# Define your host, port, and payload here based on the environment
case $ENV in
  dev)
    declare -A HOSTS=(["host1"]="dev.host1.api.payload:2181" ["host2"]="dev.host2.api.payload:2181" ["host3"]="dev.host3.api.payload:2181")
    ;;
  qa)
    declare -A HOSTS=(["host1"]="qa.host1.api.payload:2181" ["host2"]="qa.host2.api.payload:2181" ["host3"]="qa.host3.api.payload:2181")
    ;;
  nfr)
    declare -A HOSTS=(["host1"]="nfr.host1.api.payload:2181" ["host2"]="nfr.host2.api.payload:2181" ["host3"]="nfr.host3.api.payload:2181")
    ;;
  *)
    echo "Unknown environment: $ENV"
    exit 1
    ;;
esac

stop_node() {
  local host=$1
  local port=$2
  # Make API call to stop the node
  echo "Stopping $host:$port"
  # Placeholder for API call:
  # curl -X POST "http://$host:$port/zk.api/stop"
}

start_node() {
  local host=$1
  local port=$2
  # Make API call to start the node
  echo "Starting $host:$port"
  # Placeholder for API call:
  # curl -X POST "http://$host:$port/zk.api/start"
}

get_zk_status() {
  local host_port=(${1//:/ })
  local host=${host_port[0]}
  local port=${host_port[1]}

  # Using netcat to get the status of the Zookeeper node
  echo stat | nc $host $port | grep Mode
}

stop_cluster() {
  local leader=""
  local followers=()

  # Determine the leader and followers
  for host_port in "${HOSTS[@]}"; do
    mode=$(get_zk_status "$host_port")
    if [[ $mode == *"leader"* ]]; then
      leader=$host_port
    else
      followers+=($host_port)
    fi
  done

  # Record leader and followers information
  echo "Leader: $leader" > "$LEADERINFO_FILE"
  echo "Followers: ${followers[*]}" >> "$LEADERINFO_FILE"

  # Stop followers first
  for follower in "${followers[@]}"; do
    stop_node ${follower//:/ }
  done

  # Then stop the leader
  if [ -n "$leader" ]; then
    stop_node ${leader//:/ }
  else
    echo "Could not determine the leader to stop."
  fi
}

start_cluster() {
  if [ ! -f "$LEADERINFO_FILE" ]; then
    echo "Leader info file not found."
    exit 1
  fi

  # Read leader and followers from the file
  local leader=$(grep 'Leader' "$LEADERINFO_FILE" | cut -d ' ' -f 2)
  local followers=($(grep 'Followers' "$LEADERINFO_FILE" | cut -d ' ' -f 2-))

  # Start the leader first
  if [ -n "$leader" ]; then
    start_node ${leader//:/ }
  fi

  # Start followers
  for follower in "${followers[@]}"; do
    start_node ${follower//:/ }
  done
}

case $ACTION in
  stop)
    stop_cluster
    ;;
  start)
    for host_port in "${HOSTS[@]}"; do
      if get_zk_status "$host_port" > /dev/null; then
        echo "ZooKeeper is already up on $host_port."
        exit 0
      fi
    done
    start_cluster
    ;;
  *)
    echo "Unknown action: $ACTION"
    exit 1
    ;;
esac
