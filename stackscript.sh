#!/bin/bash
set -e
trap "cleanup $? $LINENO" EXIT

##Linode/SSH security settings
#<UDF name="user_name" label="The limited sudo user to be created for the Linode" default="">
#<UDF name="password" label="The password for the limited sudo user" example="an0th3r_s3cure_p4ssw0rd" default="">
#<UDF name="disable_root" label="Disable root access over SSH?" oneOf="Yes,No" default="No">
#<UDF name="pubkey" label="The SSH Public Key that will be used to access the Linode (Recommended)" default="">

## Domain Settings
#<UDF name="token_password" label="Your Linode API token. This is needed to create your WordPress server's DNS records" default="">
#<UDF name="subdomain" label="Subdomain" example="The subdomain for the DNS record: www (Requires Domain)" default="">
#<UDF name="domain" label="Domain" example="The domain for the DNS record: example.com (Requires API token)" default="">

## K8s-vault
#<UDF name="pat_token_password" Label="Linode API token" />
#<UDF name="cluster_label" Label="A label to identify the LKE cluster" />
#<UDF name="cluster_version" Label="The Kubernetes version of your cluster" oneOf="1.26" />
#<UDF name="cluster_nodes" Label="The number of nodes for your cluster"/> 
#<UDF name="cluster_dc" Label="The datacenter for your LKE cluster" oneOf="ap-west,ca-central,ap-southeast,us-iad,us-ord,fr-par,us-central,us-west,us-southeast,us-east,eu-west,ap-south,eu-central,ap-northeast", default="us-southeast" />
#<UDF name="cluster_node_plan" Label="The plan for your cluster nodes" oneOf="g6-dedicated-2,g6-dedicated-4,g6-dedicated-8,g6-dedicated-16,g6-dedicated-32,g6-dedicated-48,g6-dedicated-50,g6-dedicated-56,g6-dedicated-64", default="g6-dedicated-8" />

# git repo
export GIT_REPO="https://github.com/jcotoBan/k8s-vault.git"
export WORK_DIR="/tmp/k8s-vault" 
export MARKETPLACE_APP="ansiblePlaybook"

# enable logging
exec > >(tee /dev/ttyS0 /var/log/stackscript.log) 2>&1

function cleanup {
  if [ -d "${WORK_DIR}" ]; then
    rm -rf ${WORK_DIR}
  fi

}

function udf {

  local group_vars="${WORK_DIR}/${MARKETPLACE_APP}/group_vars/linode/vars"
  
  if [[ -n ${USER_NAME} ]]; then
    echo "username: ${USER_NAME}" >> ${group_vars};
  else echo "No username entered";
  fi

    if [[ -n ${DISABLE_ROOT} ]]; then
    echo "disable_root: ${DISABLE_ROOT}" >> ${group_vars};
  fi

  if [[ -n ${PASSWORD} ]]; then
    echo "password: ${PASSWORD}" >> ${group_vars};
  else echo "No password entered";
  fi

  if [[ -n ${PUBKEY} ]]; then
    echo "pubkey: ${PUBKEY}" >> ${group_vars};
  else echo "No pubkey entered";
  fi

  #k8s-vault vars

  export LINODE_TOKEN="$PAT_TOKEN_PASSWORD"
  
  if [[ -n ${CLUSTER_LABEL} ]]; then
    echo "cluster_label: ${CLUSTER_LABEL}" >> ${group_vars};
  fi

    if [[ -n ${CLUSTER_VERSION} ]]; then
    echo "cluster_version: ${CLUSTER_VERSION}" >> ${group_vars};
  fi

  if [[ -n ${CLUSTER_NODES} ]]; then
    echo "cluster_nodes: ${CLUSTER_NODES}" >> ${group_vars};
  fi

  if [[ -n ${CLUSTER_DC} ]]; then
    echo "cluster_dc: ${CLUSTER_DC}" >> ${group_vars};
  fi

  if [[ -n ${CLUSTER_NODE_PLAN} ]]; then
    echo "cluster_node_plan: ${CLUSTER_NODE_PLAN}" >> ${group_vars};
  fi


}

function run {
  # install dependancies
  apt-get update
  apt-get install -y git python3 python3-pip

  # clone repo and set up ansible environment

git -C /tmp clone ${GIT_REPO}
cd ${WORK_DIR}

  # venv
  cd ${WORK_DIR}/${MARKETPLACE_APP}
  pip3 install virtualenv
  python3 -m virtualenv env
  source env/bin/activate
  pip install pip --upgrade
  pip install -r requirements.txt
  ansible-galaxy install -r collections.yml
  

  # populate group_vars
  udf
  # run playbooks
  for playbook in site.yml; do ansible-playbook -vvvv $playbook; done
  
}

function installation_complete {
  echo "Installation Complete"
}
# main
run && installation_complete
cleanup
