#!/bin/bash

# Usage: ./zk_control.sh <environment> <start|stop>

ENV="$1"
ACTION="$2"
TIMESTAMP=$(date +%Y%m%d%H%M%S)
LEADERINFO_FILE="leaderinfo_${ENV}_${TIMESTAMP}.txt"

stop_node() {
  local payload=$1
  # Make API call to stop the node
  echo "Stopping node with payload: $payload"
  # curl -X POST "http://$payload/zk.api/stop"
}

start_node() {
  local payload=$1
  # Make API call to start the node
  echo "Starting node with payload: $payload"
  # curl -X POST "http://$payload/zk.api/start"
}

get_zk_status() {
  local host=$1
  local port=$2
  echo stat | nc "$host" "$port" 2>/dev/null | grep "Mode"
}

stop_cluster() {
  local leader_payload
  local follower_payloads=()

  for payload in "${HOSTS[@]}"; do
    local host port
    IFS=':' read -r host port _ <<< "$payload"
    status=$(get_zk_status "$host" "$port")
    if [[ $status == *"leader"* ]]; then
      leader_payload=$payload
    else
      follower_payloads+=("$payload")
    fi
  done

  echo "Leader: $leader_payload" > "$LEADERINFO_FILE"
  for payload in "${follower_payloads[@]}"; do
    stop_node "$payload"
  done

  if [[ -n $leader_payload ]]; then
    stop_node "$leader_payload"
  fi
}

start_cluster() {
  if [ ! -f "$LEADERINFO_FILE" ]; then
    echo "Leader info file not found."
    exit 1
  fi

  leader_payload=$(grep 'Leader' "$LEADERINFO_FILE" | cut -d ' ' -f 2)
  if [[ -n $leader_payload ]]; then
    start_node "$leader_payload"
  fi

  follower_payloads=($(grep 'Followers' "$LEADERINFO_FILE" | cut -d ' ' -f 2-))
  for payload in "${follower_payloads[@]}"; do
    start_node "$payload"
  done
}

# Define host details within the case statement
case $ENV in
  dev)
    HOSTS=("dev.host1:2181:payload1" "dev.host2:2181:payload2" "dev.host3:2181:payload3")
    ;;
  qa)
    HOSTS=("qa.host1:2181:payload1" "qa.host2:2181:payload2" "qa.host3:2181:payload3")
    ;;
  nfr)
    HOSTS=("nfr.host1:2181:payload1" "nfr.host2:2181:payload2" "nfr.host3:2181:payload3")
    ;;
  *)
    echo "Unknown environment: $ENV"
    exit 1
    ;;
esac

if [ "$ACTION" == "stop" ]; then
  stop_cluster
elif [ "$ACTION" == "start" ]; then
  for payload in "${HOSTS[@]}"; do
    local host port
    IFS=':' read -r host port _ <<< "$payload"
    if get_zk_status "$host" "$port" > /dev/null; then
      echo "ZooKeeper is already up on $host:$port."
      exit 0
    fi
  done
  start_cluster
else
  echo "Unknown action: $ACTION"
  exit 1
fi
