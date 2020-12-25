#!/bin/bash
NFSIP=10.150.9.0/24
bastion_ip=10.150.9.100
master1_ip=10.150.9.111
master2_ip=10.150.9.112
master3_ip=10.150.9.113
worker1_ip=10.150.9.114
worker2_ip=10.150.9.115
worker3_ip=10.150.9.116
bootstrap_ip=10.150.9.110
harbor_ip=10.150.3.7
ocp_vers=4.6.6
svc_ip=172.30.0.0/16
cidr_ip=10.128.0.0/14

cat << EOF > /root/ocp4/ocp_env
export OCP_RELEASE=$ocp_vers
export LOCAL_REGISTRY='$harbor_ip'
export LOCAL_REPOSITORY='ocp4/ocp$ocp_vers' 
export PRODUCT_REPO='openshift-release-dev'
export LOCAL_SECRET_JSON='/root/ocp4/pull-secret.json'
export RELEASE_NAME='ocp-release'
export ARCHITECTURE=x86_64
EOF
source /root/ocp4/ocp_env
oc adm -a ${LOCAL_SECRET_JSON} release mirror  --from=quay.io/${PRODUCT_REPO}/${RELEASE_NAME}:${OCP_RELEASE}-${ARCHITECTURE} --to=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY} --to-release-image=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}:${OCP_RELEASE}-${ARCHITECTURE}
cat /dev/null > ~/.ssh/id_rsa
cat /dev/null > ~/.ssh/id_rsa.pub
echo "============================="
echo "============================="
echo "Please Enter"
echo "============================="
echo "============================="
ssh-keygen -t rsa -b 4096 -N ''
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_rsa
sed -i 's/^/  /g' /etc/pki/ca-trust/source/anchors/ca.crt

sleep 3

cat << EOF > /root/ocp4/install-config.yaml
apiVersion: v1
baseDomain: jjk.com
metadata:
  name: master

compute:
- hyperthreading: Enabled
  name: worker
  replicas: 0

controlPlane:
  hyperthreading: Enabled
  name: master
  replicas: 3

networking:
  clusterNetwork:
  - cidr: $cidr_ip
    hostPrefix: 24
  networkType: OpenShiftSDN
  serviceNetwork:
  - $svc_ip

platform:
  none: {}

fips: false

pullSecret: '{"auths":{"$harbor_ip":{"auth":"YWRtaW46R29vZG1pdDEh","email":"goodca@goodmit.co.kr"}}}'
sshKey: "sshKey: $(cat ~/.ssh/id_rsa.pub)"
additionalTrustBundle: |
$(cat /etc/pki/ca-trust/source/anchors/ca.crt)
imageContentSources:
- mirrors:
  - $(harbor_ip)/ocp4/$(ocp_vers)
  source: quay.io/openshift-release-dev/ocp-release
- mirrors:
  - $(harbor_ip)/ocp4/$(ocp_vers)
  source: quay.io/openshift-release-dev/ocp-v4.0-art-dev
EOF

mkdir -pv /root/ocp4/install_dir
cp -rfv /root/ocp4/install-config.yaml /root/ocp4/install_dir/install-config.yaml
cat << EOF > /root/ocp4/install_dir/manifests/cluster-scheduler-02-config.yml
apiVersion: config.openshift.io/v1
kind: Scheduler
metadata:
  creationTimestamp: null
  name: cluster
spec:
  mastersSchedulable: false
  policy:
    name: ""
status: {}
EOF
openshift-install create ignition-configs --dir=/root/ocp4/install_dir/
cp -vrp /root/ocp4/install_dir/*.ign /var/www/html/ocp4/
cp -vrp /root/ocp4/install_dir/metadata.json /var/www/html/ocp4/
chmod -R 755 /var/www/html/
echo "======================================================"
curl localhost:8080/ocp4/metadata.json
