#!/usr/bin/env bash
set -v

kubectl get po --namespace=redis

kubectl get svc --namespace=redis

kubectl get rc --namespace=redis

kubectl get pvc --namespace=redis

kubectl get statefulsets --namespace=redis

kubectl get rs --namespace=redis

kubectl get secrets --namespace=redis
