#!/bin/bash

# create s3 bucket. This is where the cluster configuration is stored.
aws s3api create-bucket \
--bucket ${CLUSTER_FULL_NAME}-state \
--region eu-central-1 \
--create-bucket-configuration LocationConstraint=eu-central-1

# enable snapshot 
#aws s3api put-bucket-versioning --bucket ${CLUSTER_FULL_NAME}-state --versioning-configuration Status=Enabled

# we need to reference the s3 bucket
export KOPS_STATE_STORE="s3://${CLUSTER_FULL_NAME}-state"

kops create cluster \
--name=${CLUSTER_FULL_NAME} \
--zones=${CLUSTER_AWS_AZ} \
--master-size="t2.medium" \
--node-size="t2.medium" \
--node-count="2" \
--dns-zone=${DOMAIN_NAME} \
--ssh-public-key="~/.ssh/id_rsa.pub" \
--kubernetes-version="1.10.1" --yes

# wait until cluster comes up available!
kops validate cluster
#while [ $? -ne 0 ]; do !!; done

# now, have a look at the cluster nodes
kubectl get nodes
