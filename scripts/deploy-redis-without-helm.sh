#!/usr/bin/env bash

: "${GIT_HOME:?Need to set GIT_HOME to be base working dir for git repo}"


cd $GIT_HOME/aergo-redis/redis/templates

kubectl create namespace redis

# Create our redis secrets 'redis-credentials' from our base64 encoding passwords
#kubectl create -f redis-credentials.yaml --namespace=redis

# Create a temporary bootstrap master to be deleted upon cluster config
kubectl create -f redis-master.yaml --namespace=redis
sleep 15

# Create a redis-sentinel service to track the sentinels
#   Provides discoverable endpoints for the Redis sentinels in the cluster. 
#   From the sentinels, Redis clients can find the master, the slaves, and other relevant info for the cluster. 
#   This service enables new members to join the cluster when failures occur.
kubectl create -f redis-sentinel-service.yaml --namespace=redis
sleep 5

# Create a 'redis' rc Replication Controller with a single replica to adopt our existing Redis server
#   Note: 
#     The bulk of this controller config is actually identical to the redis-master pod definition above. 
#     It forms the template or "cookie cutter" that defines what it means to be a member of this set.
kubectl create -f redis-controller.yaml --namespace=redis
sleep 5

# Create a 'redis-sentinel' rc replication controller for redis sentinels
#   Note: 
#     The bulk of this controller config is actually identical to the redis-master pod definition above. 
#     It forms the template or "cookie cutter" that defines what it means to be a member of this set.
kubectl create -f redis-sentinel-controller.yaml --namespace=redis
sleep 5

# Scale both replication controllers
kubectl scale rc redis --replicas=3 --namespace=redis
kubectl scale rc redis-sentinel --replicas=3 --namespace=redis

sleep 5

# Delete the original master pod
# Note: If you are running all the above commands consecutively including this one in a shell script, it may NOT work out. When you run the above commands, let the pods first come up, especially the redis-master pod. Else, the sentinel pods would never be able to know the master redis server and establish a connection with it. 
echo 'delete the original master redis used to bootstrap cluster only'
kubectl delete po redis-master --namespace=redis
echo ''

echo 'kubectl get po --namespace=redis'
kubectl get po --namespace=redis
echo ''

echo 'kubectl get svc,rc --namespace=redis # List all replication controllers and services together in ps output format'
kubectl get svc,rc --namespace=redis # List all replication controllers and services together in ps output format
echo ''
