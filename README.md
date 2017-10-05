## Terradatum Redis on Kubernetes

### Ref:
* [github.com:/kubernetes/examples/tree/master/staging/storage/redis](https://github.com/kubernetes/examples/tree/master/staging/storage/redis)
* [github.com/kubernetes/charts/tree/master/stable/redis](https://github.com/kubernetes/charts/tree/master/stable/redis)


###  Our redis on kube requirements:
 - Docker image: Apline Linux
 - Stateful redis H/A (minus the persistent volume)
	 - master and slave failover, etc.
 - Redis sentinel service and IP address, etc.


### Tried helm but went with kubernetes/examples process
Our current ```deploy-redis-without-helm.sh```
script was created according to the README in kubernetes/examples/tree/master/staging/storage/redis.

This works internally for us--YMMV (I used the above noted URL's as our baselines and modified for our internal development needs).  

 * Why not just install redis via helm, right?
	*  I couldn't find an H/A stateful redis helm chart with sentinels, etc. The official version in the kubernetes charts code base doesn't seem to provide us with what we need.
	* We tried using helm, but it just didn't work for us at the time.  
		* We wanted to deploy an H/A redis solution (minus the pvc) into kube via helm, but due to timing issues, etc., I wasn't able to keep the redis helm deployment healthy post the initial redis bootstrap master termination.  I had tried various other redis deployment projects, but each one seemed to either have problems (for us) or was missing features we wanted (we were using older kubernetes 1.5.1 versions for this project), etc.  
		* I kept coming back to the recommended [kube/examples README.md#tldr](https://github.com/kubernetes/examples/blob/master/staging/storage/redis/README.md#tl-dr)
		* So that's what our ```deploy-redis-cluster.sh``` script does--see below.


### Redis cluster architecture overview summary
* Deploys two scalable redis clusters: 
	* (master/slave) and sentinel
* Sentinel service for redis requests.


### Useful alias when working with redis namespace
[Optional] Save yourself from a lot of typing using the below.
```sh
kubectl get po --namespace=redis 
# after we create the alias our command now becomes
alias kredis='kubectl --namespace redis'
kredis get po
```

### Deploy redis cluster
```sh
cd $GIT_HOME/aergo-redis
git pull && ./scripts/deploy-redis-without-helm.sh
```

### Show current redis kubernetes objects 
* Note: You can also use the ```show-redis.sh``` script which runs the below and more commands.


```sh
kubectl get po --namespace=redis
NAME                   READY     STATUS    RESTARTS   AGE
redis-kr6k2            1/1       Running   0          15h
redis-r30gt            1/1       Running   0          15h
redis-sentinel-5g3z2   1/1       Running   0          15h
redis-sentinel-gv0bp   1/1       Running   0          15h
redis-sentinel-qpks1   1/1       Running   0          15h
redis-vmlg0            1/1       Running   0          15h

kubectl get svc --namespace=redis
NAME             CLUSTER-IP   EXTERNAL-IP   PORT(S)     AGE
redis-sentinel   10.3.0.167   <none>        26379/TCP   15h

kubectl get rc --namespace=redis
NAME             DESIRED   CURRENT   READY     AGE
redis            3         3         3         15h
redis-sentinel   3         3         3         15h
```


### Source script to set your current shell ENV with useful variables
 We also provide tools and utilities for working with redis, such as dynamically maintaining redis server and sentinel cluster member names and their IP's in developers' environments--see the ```source-redis-cluster-vars.sh``` script (see below) for this.  
 
You will want/need to know the pods and their IP addresses in the clusters and the sentinel service IP using the:
```source-redis-cluster-vars.sh``` script.

```sh
source ./scripts/source-redis-cluster-vars.sh

sentinel_cluster pods (cluster state mgmt):
sentinel: redis-sentinel-5g3z2 10.2.93.242
sentinel: redis-sentinel-gv0bp 10.2.77.136
sentinel: redis-sentinel-qpks1 10.2.77.138

redis_cluster pods (master and slaves):
redis: redis-kr6k2 10.2.77.137
redis: redis-r30gt 10.2.93.241
redis: redis-vmlg0 10.2.77.139

NOW UPDATING ENV VARS if you've sourced this script correctly (source source-redis-cluster-vars.sh)

'$redis_cluster' ENV var should be set to:
redis-kr6k2 redis-r30gt redis-vmlg0

'$sentinel_cluster' ENV var should be set to:
redis-sentinel-5g3z2 redis-sentinel-gv0bp redis-sentinel-qpks1

'$sentinel_service' ENV var should be set to:
10.3.0.167
```

### Scale redis cluster replication controllers
In this example, we scale from three (3) to five (5).
```sh
kubectl get rc --namespace=redis
NAME             DESIRED   CURRENT   READY     AGE
redis            3         3         3         16h
redis-sentinel   3         3         3         16h

kubectl scale rc redis --replicas=5 --namespace=redis
replicationcontroller "redis" scaled

kubectl scale rc redis-sentinel --replicas=5 --namespace=redis
replicationcontroller "redis-sentinel" scaled

kubectl get rc --namespace=redis
NAME             DESIRED   CURRENT   READY     AGE
redis            5         5         5         16h
redis-sentinel   5         5         5         16h
```

### Run commands on every redis pod example
```sh
alias kredis='kubectl --namespace redis'
for REDIS_POD in $(kredis get po | grep -v 'NAME' | awk '{print $1}'); do kredis exec -it $REDIS_POD -- env | grep MY_POD ; echo; done
# outputs the following for each pod in the redis and setinel clusters
MY_POD_NAME=redis-kr6k2
MY_POD_NAMESPACE=redis
MY_POD_IP=10.2.77.137

MY_POD_NAME=redis-sentinel-5g3z2
MY_POD_NAMESPACE=redis
MY_POD_IP=10.2.93.242
...
```

### Show redis master/slave server status
Poll from the current redis_cluster nodes:
```sh
for i in $redis_cluster; do echo "redis-server: $i"; kredis exec $i -- redis-cli info | grep ^role ; done
redis-server: redis-jpxdt
role:master
redis-server: redis-t4t1q
role:slave
redis-server: redis-zs0sg
role:slave
```

### Show sentinels master server
Poll from the current sentinel_cluster nodes:
```sh
for i in $sentinel_cluster; do echo "----- redis-sentinel info: $i -----"; kredis exec $i -- redis-cli -p 26379 SENTINEL get-master-addr-by-name mymaster ; done
----- redis-sentinel info: redis-sentinel-9wcpj -----
10.2.77.156
6379
----- redis-sentinel info: redis-sentinel-nhbgg -----
10.2.77.156
6379
----- redis-sentinel info: redis-sentinel-x4t4j -----
10.2.77.156
6379
```

### Show current redis cluster stats via sentinel query
Run query on the redis_cluster nodes:
```sh
for i in $sentinel_cluster; do echo "----- redis-sentinel info: $i -----"; kredis exec $i -- redis-cli -p 26379  -h localhost -p 26379 info | grep status; echo; done
# ref: https://github.com/antirez/redis/issues/1972
# strange sentinel count seems to be a known issue or "feature?" here.
----- redis-sentinel info: redis-sentinel-9wcpj -----
master0:name=mymaster,status=ok,address=10.2.77.156:6379,slaves=3,sentinels=4

----- redis-sentinel info: redis-sentinel-nhbgg -----
master0:name=mymaster,status=ok,address=10.2.77.156:6379,slaves=3,sentinels=4

----- redis-sentinel info: redis-sentinel-x4t4j -----
master0:name=mymaster,status=ok,address=10.2.77.156:6379,slaves=3,sentinels=4
```

### Notes
At the time and with our kubernetes version (1.5.1) [kubernetes statefulsets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/) was and is still a beta feature.  This appears like the correct kubernetes object to utilize moving forward, since we require ordered operations.


### TODO
 * Refactor for redis password auth, currently we allow connections without auth/password--this is currently suitable and used in a **development** kubernetes cluster and environment--**Do not use in prod without password authentication**.
 * Refactor for helm chart installation, perhaps with newer kubernetes objects such as 
  [kubernetes statefulset](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/) etc., to provide ordered, graceful deployment and scaling.  On this note all our '.yaml' files are in the required path (redis/templates) for future helm implementation.
 *  Test and refactor using latest kubernetes 1.7.4+ version on our newer clusters.