#!/usr/bin/env bash


. /container.init/common.sh

function process_config {
    mkdir -p  /etc/neutron/plugins/ml2/

    cp /neutron-etc/neutron.conf /etc/neutron/neutron.conf
    cp /neutron-etc/logging.conf /etc/neutron/logging.conf
    cp /neutron-etc/ml2-conf.ini /etc/neutron/plugins/ml2/ml2_conf.ini
    cp /neutron-etc/rootwrap.conf /etc/neutron/rootwrap.conf
    cp /neutron-etc/neutron-policy.json /etc/neutron/policy.json
    cp /neutron-etc/sudoers /etc/sudoers
}

process_config

exec neutron-openvswitch-agent --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini
