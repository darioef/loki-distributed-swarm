# Grafana Loki cluster using Docker in Swarm mode

This project allows you to install and run Grafana Loki for production in [microservices mode](https://grafana.com/docs/loki/latest/fundamentals/architecture/#microservices-mode) using Docker in Swarm mode.

This is useful if you don't want to deal with a Kubernetes Cluster or if running Loki in monolithic mode is not enough for your production environment.

___

Table of contents:

- [Grafana Loki cluster using Docker in Swarm mode](#grafana-loki-cluster-using-docker-in-swarm-mode)
- [Features](#features)
- [Requirements](#requirements)
- [Configuration](#configuration)
- [Deploy](#deploy)
  - [Create stack](#create-stack)
  - [Check if all services/replicas are running](#check-if-all-servicesreplicas-are-running)
  - [Distributor Ring](#distributor-ring)
  - [Remove stack](#remove-stack)
- [Customization](#customization)
  - [Load balancer (Optional)](#load-balancer-optional)
  - [Resources](#resources)
  - [Retention](#retention)
  - [Enable Basic Auth (Optional)](#enable-basic-auth-optional)
- [Authors](#authors)
- [Acknowledgments](#acknowledgments)


# Features

* Components:
  * Query Frontend
  * Distributor
  * Ingester
  * Querier
  * Index Gateway
  * Compactor
* Caching
  * Memcached for Index
  * Memcached for Chunks
  * Memcached for Results (query-frontend)
* Gateway
  * Nginx as API Gateway
* Backend
  * AWS S3 (could be changed for MinIO support)
* KV Store
  * Uses native Loki memberlist
* Loki versions supported
  * 2.4.2 (latest stable)
  * 2.3.0 (need to replace tags in docker-compose.yaml)


# Requirements

* Docker in Swarm mode: 3 masters + 1 worker (installation/configuration not covered here)
* AWS ALB or any load balancer to route incomming traffic to your Docker nodes
* AWS S3 bucket (or compatible)
* AWS IAM User + Policy attached with RW permissions on the S3 Bucket.

> Note: The size of the instances depends of the amount of data that will be ingested/queried. Try to be generous.

# Configuration

1. Create a private AWS S3 Bucket.

2. Create an AWS IAM Policy with the following name/content and replace `<YOUR BUCKET NAME>` with the name of the bucket created in the previous step (remove 'less than' and 'greater than' symbols).


    ```S3-Loki-RW```
    ```json
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": [
                    "s3:PutObject",
                    "s3:GetObject",
                    "s3:DeleteObject",
                    "s3:ListObjects",
                    "s3:ListBucket"
                ],
                "Resource": [
                    "arn:aws:s3:::<YOUR BUCKET NAME>/*",
                    "arn:aws:s3:::<YOUR BUCKET NAME>"
                ]
            }
        ]
    }
    ```

3. Create an AWS IAM User (Access key - Programmatic access) and attach the policy previously created. Save the access key ID and the secret access key in a safe place for future use.

4. Tag your Docker worker node with the label `loki-extras=true`.

    ```shell
    docker node update <your_docker_worker_node_name> --label-add loki-extras=true
    ```

This node will be used to run compactor, index-gateway and memcached containers isolated from the other components.

5. Clone this repo in any master node of your cluster.

    ```shell
    cd /opt
    git clone https://github.com/darioef/loki-distributed-swarm.git
    ```

6. Open the recently created directory, edit AWS.env file located at the root of the project and complete the environment variables's values needed for Loki to connect to your S3 Bucket using the credentials created in step 3.

    ```
    AWS_BUCKETNAME=                                 # Insert your AWS S3 Bucketname here
    AWS_ENDPOINT=                                   # Insert your AWS S3 Endpoint based on your region. Example: s3.us-east-1.amazonaws.com
    AWS_REGION=                                     # Insert your AWS S3 Region. Example: us-east-1
    AWS_ACCESS_KEY_ID=                              # Insert your AWS Access Key with S3 read/write permissions to S3 and your bucket.
    AWS_SECRET_ACCESS_KEY=                          # Insert your AWS Secret Access Key
    ```

# Deploy

Change to project's directory:
```bash
cd /opt/loki-distributed-swarm
```

## Create stack

```bash
docker stack deploy -c docker-compose.yaml loki-distributed
```

Output:
```
Creating network loki-distributed-swarm_loki
Creating network loki-distributed-swarm_nginx
Creating config loki-distributed-swarm_nginx-conf
Creating config loki-distributed-swarm_loki-entrypoint
Creating config loki-distributed-swarm_loki-conf
Creating service loki-distributed-swarm_memcached-chunks
Creating service loki-distributed-swarm_loki-distributor
Creating service loki-distributed-swarm_memcached-query-frontend
Creating service loki-distributed-swarm_loki-gateway
Creating service loki-distributed-swarm_memcached-index
Creating service loki-distributed-swarm_loki-index-gateway
Creating service loki-distributed-swarm_loki-querier
Creating service loki-distributed-swarm_loki-query-frontend
Creating service loki-distributed-swarm_loki-compactor
Creating service loki-distributed-swarm_loki-ingester
```

## Check if all services/replicas are running

```bash
docker service ls
```

Output:

```
ID             NAME                                        MODE         REPLICAS                 IMAGE                PORTS
xqdepob704xp   loki-distributed-swarm_loki-compactor             replicated   1/1                      grafana/loki:2.3.0
nhdl3gk2xl7c   loki-distributed-swarm_loki-distributor           replicated   3/3 (max 1 per node)     grafana/loki:2.3.0
xcbfvpmlo1gv   loki-distributed-swarm_loki-index-gateway         replicated   1/1 (max 4 per node)     grafana/loki:2.3.0
hebpovbmixca   loki-distributed-swarm_loki-ingester              replicated   3/3 (max 1 per node)     grafana/loki:2.3.0
mmbq91hhdota   loki-distributed-swarm_loki-querier               replicated   12/12 (max 4 per node)   grafana/loki:2.3.0
dzwj1o8rxesr   loki-distributed-swarm_loki-query-frontend        replicated   3/3                      grafana/loki:2.3.0
qz4i4m7rgfu1   loki-distributed-swarm_memcached-chunks           replicated   1/1                      memcached:1.6
3tswwa7qn0nm   loki-distributed-swarm_memcached-index            replicated   1/1                      memcached:1.6
sey2zdh2kafn   loki-distributed-swarm_memcached-query-frontend   replicated   1/1                      memcached:1.6
```

## Distributor Ring

Check if all of the members of the distributor ring are in ACTIVE state,

Open your browser and navigate to: ```http://<ANY NODE IP>/ring```

Once all members are in ACTIVE state you can start to ingest logs.

## Remove stack

In case you need to completely remove the stack, run the following command:

```
docker stack rm loki-distributed-swarm
```

# Customization

## Load balancer (Optional)
It's recommended to put a Load Balancer (AWS ALB, HAproxy, etc.) in front of the Docker Nodes to balance the ingress traffic through all the cluster nodes. Also you may want to create a DNS record resolving the IP address of the LB.

All nodes are listening at port 80/tcp (routing mesh) and you can use the /ring endpoint for the healthcheck.

If you decide not to use an LB, you can configure Loki's Grafana datasource or ingest (Promtail, Docker Plugin, etc.) using any of the nodes IP addresses at port 80/tcp.

## Resources
Feel free to change the number of replicas or resources limits of each service to fit your needs. You may also need to change some values in Loki configuration (loki-docker.yaml).

## Retention
Compactor is configured to drop logs older than 7 days. You can change the retention time in the "limits_config" section of the Loki configuration.

```
limits_config:
  retention_period: 168h
```

## Enable Basic Auth (Optional)
You can enable Basic Auth at Nginx level in order to add a security layer to your cluster. It's disabled by default.

Please, refer to docker-compose.yaml comments for more information.


# Authors
* Darío Fernández - [darioef](https://github.com/darioef)

# Acknowledgments
* Thanks to the Grafana team for such an awesome product.
* Thanks to the members of the #loki channel of the Grafana Labs Community on Slack.
