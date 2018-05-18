#!/bin/bash

# Your domain name that is hosted in AWS Route 53
export DOMAIN_NAME="rippel.no"
# Friendly name to use as an alias for your cluster
export CLUSTER_ALIAS="c01"
# Leave as-is: Full DNS name of you cluster
export CLUSTER_FULL_NAME="${CLUSTER_ALIAS}.${DOMAIN_NAME}"
# AWS availability zone where the cluster will be created
export CLUSTER_AWS_AZ="eu-central-1a"
# we need the AWS_ZONE_ID when working with route53
export DOMAIN_NAME_ZONE_ID=$(aws route53 list-hosted-zones --output json \
       | jq -r '.HostedZones[] | select(.Name=="'${DOMAIN_NAME}'.") | .Id' \
       | sed 's/\/hostedzone\///')
export KOPS_STATE_STORE="s3://${CLUSTER_FULL_NAME}-state"

# version of our hugo static site generator (world's fastest!)
export HUGO_VERSION=0.40
# configure github
export GITHUB_USERNAME="bjarteb"
# We need this token in order to permanently delete a github repo.
export GITHUB_TOKEN=$(cat ./private/github_token)
# Set your Docker Hub username 
export DOCKER_HUB_USERNAME="bjarteb"
# name of our application
export SITE=kube-app


cat <<EOF
domain name: ${DOMAIN_NAME} 
cluster alias: ${CLUSTER_ALIAS}
cluster full name: ${CLUSTER_FULL_NAME}
AWS availability zone: ${CLUSTER_AWS_AZ}
AWS domain zone id: ${DOMAIN_NAME_ZONE_ID}
KOPS state store: ${KOPS_STATE_STORE}
HUGO version: ${HUGO_VERSION}
github.com username: ${GITHUB_USERNAME}
github.com token: ***************************
dockerhub.com username: ${DOCKER_HUB_USERNAME}
Webapp name: ${SITE}
EOF
