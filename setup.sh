#!/bin/bash

# ---- Configuration ----
CLUSTER_SECRET="f9c5d0ab2a69449a83a3a5b9db9c7f48a48e1c2d1f0c41a48e2617d5b6472c44"
SWARM_KEY_CONTENT="/key/swarm/psk/1.0.0/
/base16/
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

# ---- Functions ----

install_kubo() {
    if ! command -v ipfs &> /dev/null; then
        echo "Installing Kubo (IPFS)..."
        wget https://dist.ipfs.tech/kubo/v0.29.0/kubo_v0.29.0_linux-amd64.tar.gz
        tar -xvzf kubo_v0.29.0_linux-amd64.tar.gz
        sudo mv kubo/ipfs /usr/local/bin/
    else
        echo "Kubo (IPFS) already installed."
    fi
}

install_ipfs_cluster() {
    if ! command -v ipfs-cluster-service &> /dev/null; then
        echo "Installing IPFS Cluster Service..."
        wget https://dist.ipfs.tech/ipfs-cluster-service/v1.0.6/ipfs-cluster-service_v1.0.6_linux-amd64.tar.gz
        tar -xvzf ipfs-cluster-service_v1.0.6_linux-amd64.tar.gz
        sudo mv ipfs-cluster-service/ipfs-cluster-service /usr/local/bin/
    else
        echo "IPFS Cluster Service already installed."
    fi

    if ! command -v ipfs-cluster-ctl &> /dev/null; then
        echo "Installing IPFS Cluster CTL..."
        wget https://dist.ipfs.tech/ipfs-cluster-ctl/v1.0.6/ipfs-cluster-ctl_v1.0.6_linux-amd64.tar.gz
        tar -xvzf ipfs-cluster-ctl_v1.0.6_linux-amd64.tar.gz
        sudo mv ipfs-cluster-ctl/ipfs-cluster-ctl /usr/local/bin/
    fi
}

install_yq() {
    if ! command -v yq &> /dev/null; then
        echo "Installing yq (YAML processor)..."
        sudo apt-get update -y
        sudo apt-get install -y wget jq curl
        sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq
        sudo chmod +x /usr/bin/yq
    fi
}

setup_ipfs() {
    echo "Initializing IPFS..."
    ipfs init

    echo "Setting up Swarm Key..."
    mkdir -p ~/.ipfs
    echo -e "$SWARM_KEY_CONTENT" > ~/.ipfs/swarm.key
}

setup_cluster() {
    echo "Initializing IPFS Cluster Service..."
    ipfs-cluster-service init

    echo "Updating Cluster Secret..."
    sed -i "s/\"secret\": \".*\"/\"secret\": \"$CLUSTER_SECRET\"/" ~/.ipfs-cluster-service/service.json

    echo "Setting replication settings..."
    yq eval ".replication_factor_min = 2" -i ~/.ipfs-cluster-service/service.json
    yq eval ".replication_factor_max = 3" -i ~/.ipfs-cluster-service/service.json
}

start_services() {
    echo "Starting IPFS daemon..."
    nohup ipfs daemon > ipfs.log 2>&1 &

    sleep 5

    echo "Starting IPFS Cluster daemon..."
    nohup ipfs-cluster-service daemon > cluster.log 2>&1 &
}

save_peerid() {
    echo "Saving this node's Cluster PeerID..."
    sleep 5
    PEER_ID=$(ipfs-cluster-ctl id | jq -r .id)
    echo "$PEER_ID" > peerid.txt
    echo "Saved Cluster PeerID to peerid.txt: $PEER_ID"
}

# ---- Execute ----
install_kubo
install_ipfs_cluster
install_yq
setup_ipfs
setup_cluster
start_services
save_peerid

echo "Bootstrap node setup complete! Share this IP and PeerID with other nodes."
