#!/bin/bash

###############################################################################
# rolling back deployment
###############################################################################

mkdir -p ./manifests/rollback

# create a manifest file for our deployment
cat > ./manifests/rollback/deployment.yaml <<EOF
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: ${SITE}
spec:
  minReadySeconds: 20
  replicas: 6
  template:
    metadata:
      labels:
        app: ${SITE}
    spec:
      containers:
        - name: ${SITE}
          image: ${DOCKER_HUB_USERNAME}/${SITE}:t1
          ports:
            - containerPort: 80
EOF

cat > ./manifests/rollback/service.yaml <<EOF
apiVersion: v1
kind: Service
metadata:
  name: ${SITE}-svc
  labels:
    app: ${SITE}
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
    name: http
  selector:
    app: ${SITE}
EOF

# setting the '-record' option when creating the initial deployment
# will record the commands for all future update made to the deployment
kubectl create -f ./manifests/rollback --record

# Set the DNS record prefix & the Service name and then retrieve the ELB URL
DNS_RECORD_PREFIX="${SITE}"
SERVICE_NAME="${SITE}-svc"
KUBE_APP_ELB=$(kubectl get svc/${SERVICE_NAME} \
--template="{{range .status.loadBalancer.ingress}} {{.hostname}} {{end}}")
# Add to JSON file
sed -i -e 's|"Name": ".*|"Name": "'"${DNS_RECORD_PREFIX}.${DOMAIN_NAME}"'",|g' \
./scripts/dns-record-single.json
sed -i -e 's|"Value": ".*|"Value": "'$(echo "${KUBE_APP_ELB}"|xargs)'"|g' \
./scripts/dns-record-single.json
# Update DNS record
aws route53 change-resource-record-sets \
--hosted-zone-id ${DOMAIN_NAME_ZONE_ID} \
--change-batch file://scripts/dns-record-single.json

# now update with t2
kubectl set image deploy/${SITE} \
  ${SITE}=${DOCKER_HUB_USERNAME}/${SITE}:t2

# list rollout history
kubectl rollout history deployment ${SITE}

# undo rollout (back to red)
kubectl rollout undo deploy/${SITE}

# make some history
kubectl set image deploy/${SITE} \
        ${SITE}=${DOCKER_HUB_USERNAME}/${SITE}:t1
kubectl set image deploy/${SITE} \
        ${SITE}=${DOCKER_HUB_USERNAME}/${SITE}:t2
kubectl set image deploy/${SITE} \
        ${SITE}=${DOCKER_HUB_USERNAME}/${SITE}:t1

# list rollout history
kubectl rollout history deployment ${SITE}
# go back to revsision 5
kubectl rollout undo deploy/${SITE} --to-revision=5

# we have demonstrated rolling back deployment
kubectl delete deploy ${SITE}
kubectl delete svc ${SITE}-svc

