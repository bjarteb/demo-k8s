#!/bin/bash

# delete cluster
kops delete cluster ${CLUSTER_FULL_NAME} --yes
# if not empty, cannot be removed
aws s3api delete-bucket --bucket ${CLUSTER_FULL_NAME}-state
