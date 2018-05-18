#!/bin/bash
###############################################################################
# rolling updates
###############################################################################
set -x

mkdir -p ./manifests/update

read -p "Let's create our first blog-app deployment! Press enter to continue"

# create a manifest file for our deployment
cat > ./manifests/update/deployment.yaml <<EOF
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: ${SITE}
spec:
  minReadySeconds: 20
  replicas: 1
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

# deploy!
kubectl create -f manifests/update/deployment.yaml

## we bring up a single pod. No manifest file.
#kubectl create deployment ${SITE} \
# --image=${DOCKER_HUB_USERNAME}/${SITE}:t1
#
## Without manifest file we need to set containerPort
#spec:
#  minReadySeconds: 20
#containers:
#  ports:
#  - containerPort: 80
#    protocol: TCP
#kubectl edit deployment ${SITE}

# scale the application
kubectl scale deployment ${SITE} --replicas 6
# expose the service (load balancer)
kubectl expose deployment ${SITE} --name=${SITE}-svc \
--type=LoadBalancer --port=80 --target-port=80

read -p "Scale out and create load balancer. Press enter to continue"

# Set the DNS record prefix & the Service name and then retrieve the ELB URL
export DNS_RECORD_PREFIX="${SITE}"
export SERVICE_NAME="${SITE}-svc"
export KUBE_APP_ELB=$(kubectl get svc/${SERVICE_NAME} \
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

read -p "Configure DNS in AWS route53... Press enter to continue"

# now update the docker image and pause
kubectl set image deploy/${SITE} \
  ${SITE}=${DOCKER_HUB_USERNAME}/${SITE}:t2; \
  kubectl rollout pause deploy/${SITE}

## monitor from second shell (shell 2)
#kubectl rollout status deploy/${SITE}

# back to shell 1. resume! watch shell 2
kubectl rollout resume deploy/${SITE}

read -p "Delete deployment. Press enter to finish"

# we have demonstrated rolling updates. Now destroy.
kubectl delete deploy ${SITE}
kubectl delete svc ${SITE}-svc


