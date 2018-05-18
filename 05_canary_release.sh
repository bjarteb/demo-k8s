#!/bin/bash

###############################################################################
# canary deployments
###############################################################################

mkdir -p ./manifests/canary

cat > ./manifests/canary/${SITE}-deploy-t1.yaml <<EOF
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: ${SITE}-t1
spec:
  replicas: 3
  template:
    metadata:
      labels:
        app: ${SITE}-canary
        track: stable
    spec:
      containers:
        - name: ${SITE}
          image: ${DOCKER_HUB_USERNAME}/${SITE}:t1
          ports:
            - containerPort: 80
EOF

cat > ./manifests/canary/${SITE}-deploy-t2.yaml <<EOF
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: ${SITE}-t2
spec:
  replicas: 3
  template:
    metadata:
      labels:
        app: ${SITE}-canary
        track: canary
    spec:
      containers:
        - name: ${SITE}
          image: ${DOCKER_HUB_USERNAME}/${SITE}:t2
          ports:
            - containerPort: 80
EOF

cat > ./manifests/canary/${SITE}-canary-svc.yaml <<EOF
apiVersion: v1
kind: Service
metadata:
  name: ${SITE}-canary-svc
  labels:
    app: ${SITE}-canary
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
    name: http
  selector:
    app: ${SITE}-canary
EOF

# deploy t1
kubectl create -f ./manifests/canary/${SITE}-deploy-t1.yaml
kubectl create -f ./manifests/canary/${SITE}-canary-svc.yaml

# Set the DNS record prefix & the Service name and then retrieve the ELB URL
export DNS_RECORD_PREFIX="${SITE}"
export SERVICE_NAME="${SITE}-canary-svc"
export KUBE_APP_ELB=$(kubectl get svc/${SERVICE_NAME} \
--template="{{range .status.loadBalancer.ingress}} {{.hostname}} {{end}}")

# Add to JSON file
sed -i -e 's|"Name": ".*|"Name": "'"${DNS_RECORD_PREFIX}.${DOMAIN_NAME}"'",|g' \
./scripts/dns-record-single.json
sed -i -e 's|"Value": ".*|"Value": "'$(echo "${KUBE_APP_ELB}" |xargs)'"|g' \
./scripts/dns-record-single.json

# Create DNS record
aws route53 change-resource-record-sets \
--hosted-zone-id ${DOMAIN_NAME_ZONE_ID} \
--change-batch file://scripts/dns-record-single.json

# we are interested in the selector information 
# app=$SITE & track=stable
kubectl describe deploy ${SITE}

# now, deploy our canary! 
# app=$SITE & track=canary
kubectl create -f ./manifests/canary/${SITE}-deploy-t2.yaml

# 25% chance of hit for t2!
kubectl get pods --label-columns=track

# rescale, now the majority are t2.
kubectl scale deployment ${SITE}-t2 --replicas=3
kubectl scale deployment ${SITE}-t1 --replicas=1

# similar procedure for blue/green deployments
# kubectl set selector svc/myserver-svc track=blue/green

# we have demonstrated canary release. destroy.
kubectl delete deployment ${SITE}-t1
kubectl delete deployment ${SITE}-t2
kubectl delete svc ${SITE}-canary-svc
