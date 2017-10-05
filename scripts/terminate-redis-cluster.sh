#!/usr/bin/env bash

# delete the redis (master and slave) recplication controller
kubectl delete rc redis redis-sentinel --namespace=redis

# delete the redis-sentinel service
kubectl delete svc redis-sentinel --namespace=redis

# Delete existing redis client replicasets with something like
# kubectl get rs --namespace=redis
# NAME                      DESIRED   CURRENT   READY     AGE
# redis-client-3381644995   0         0         0         17h
# 
# kredis delete rs redis-client-3381644995


kubectl get po,rc,svc --namespace=redis | grep redis


#kubectl get po --namespace=redis
#
#kubectl get svc --namespace=redis
#
#kubectl get rc --namespace=redis
#
#kubectl get pvc --namespace=redis
#
#kubectl get statefulsets --namespace=redis


