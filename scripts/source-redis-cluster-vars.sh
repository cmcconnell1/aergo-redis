#!/usr/bin/env bash
#
# Usage:  
# source $0
# 
# Info:
# Print current pods in both the redis_cluster and the sentinel_cluster 
#   echo "$redis_cluster" | xargs
#   echo "$sentinel_cluster" | xargs

: "${KUBECONFIG:?Need to set KUBECONFIG non-empty}"

# make sure aliases work in commands--especially remote ssh calls, etc:
shopt -s expand_aliases

export KREDIS="kubectl --namespace=redis"

printf "\nsentinel_cluster pods (cluster state mgmt):\n"
sentinel_cluster=$($KREDIS get po | grep redis-sentinel| grep -v "NAME" | awk '{print $1}' | xargs)
for sentinel_pod in $sentinel_cluster; do
    printf "sentinel: $sentinel_pod "
    $KREDIS describe pod $sentinel_pod | grep IP | awk '{print $2}' | grep -v 'v1:status.podIP'
done

printf "\nredis_cluster pods (master and slaves):\n"
redis_cluster=$($KREDIS get po | grep -v redis-sentinel | grep -v "NAME" | awk '{print $1}' | xargs)
for redis_pod in $redis_cluster; do
    printf "redis: $redis_pod "
    $KREDIS describe pod $redis_pod | grep IP | awk '{print $2}' | grep -v 'v1:status.podIP'
done

sentinel_service=$($KREDIS get svc | grep redis-sentinel | awk '{print $3}')

printf "\nNOW UPDATING ENV VARS if you've sourced this script correctly (source source-redis-cluster-vars.sh)\n"
printf "\n'\$redis_cluster' ENV var should be set to:\n$redis_cluster\n"
printf "\n'\$sentinel_cluster' ENV var should be set to:\n$sentinel_cluster\n"
printf "\n'\$sentinel_service' ENV var should be set to:\n$sentinel_service\n"

printf "\n"

#printf "\nprintf \$redis_cluster\n $redis_cluster\n\n"
#printf "\nprintf \$sentinel_cluster\n $sentinel_cluster\n\n"
#printf "\nprintf \$sentinel_service:\n$sentinel_service\n\n"
