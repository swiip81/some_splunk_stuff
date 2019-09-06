#!/bin/bash
# Performing a full splunk cluster reboot as kindly as possible
# Script used by a jenkins job including ssh keys for splunk and root user

COLOR_GREEN="\\033[1;32m"; COLOR_RED="\\033[1;31m"; COLOR_WHITE="\\033[0;39m"; COLOR_YELLOW="\\033[0;33m"; COLOR_CYAN="\\033[1;36m"
echo_green() { echo -e "$COLOR_GREEN$1$COLOR_WHITE"; }
echo_red() { echo -e "$COLOR_RED$1$COLOR_WHITE"; }
echo_white() { echo -e "$COLOR_WHITE$1$COLOR_WHITE"; }
echo_yellow() { echo -e "$COLOR_YELLOW$1$COLOR_WHITE"; }
echo_cyan() { echo -e "$COLOR_CYAN$1$COLOR_WHITE"; }
echo_date() { echo -e "$COLOR_CYAN$(date)$COLOR_WHITE"; }
dash_line="--------------------------------------------------------------------------------------------"

# Variables
# Fill that the way you want 
SPLK_USER=your_splk_admin_user
SPLK_PASS=your_splk_admin_password

MASTER=mn1.exemple.net
INDEXERS=( idx1.exemple.net \
           idx2.exemple.net \
           idx3.exemple.net \
           idx4.exemple.net )
SHANDHF=( hf1.exemple.net \
          sh1.exemple.net \
          sh2.exemple.net \
          sh3.exemple.net \
          ds1.exemple.net )
UF=( uf1.exemple.net \
     uf2.exemple.net \
     uf3.exemple.net )

# Functions

enable_maintenancemode()
{
    echo_date
    echo_green "${MASTER} Set maintenance mode"
    ssh -o StrictHostKeyChecking=no "${MASTER}" -l splunk -- "/opt/splunk/bin/splunk enable maintenance-mode --answer-yes -auth "${SPLK_USER}":${SPLK_PASS}"
    sleep 10s
}

disable_maintenancemode()
{
    echo_date
    echo_green "${MASTER} Disable maintenance mode"
    ssh -o StrictHostKeyChecking=no "${MASTER}" -l splunk -- "/opt/splunk/bin/splunk disable maintenance-mode -auth "${SPLK_USER}":${SPLK_PASS}"  
    echo_green "${MASTER} Now waiting all green status"
    while [[ $(ssh -o StrictHostKeyChecking=no "${MASTER}" -l splunk -- /opt/splunk/bin/splunk show cluster-status -auth "${SPLK_USER}":"${SPLK_PASS}" | grep -cF 'factor not met') -ne 0 ]] ; do sleep 10s ; done
    echo_green "${MASTER} All green"
}

stop_splunk()
{
    echo_date
	echo_green "${1} Stoping splunk"
    ssh -o StrictHostKeyChecking=no "${1}" -l splunk -- "/opt/splunk/bin/splunk stop"
}

offline_splunk()
{
    echo_date
	echo_green "${1} Put offline splunk"
	ssh -o StrictHostKeyChecking=no "${1}" -l splunk -- "/opt/splunk/bin/splunk offline -auth "${SPLK_USER}":${SPLK_PASS}"
}

go_reboot()
{
    echo_date
	echo_green "${1} Reboot"
    ssh -o StrictHostKeyChecking=no "${1}" -l root -- reboot
}

wait_online_status()
{
    echo_date
    echo_green "${1} Waiting online status + ${2}s"
	while ! $(echo quit | curl -s -m1 telnet://${1}:8089 &>/dev/null) ; do sleep 5s ; done ; sleep "${2}"s
    echo_green "${1} Done" 
}

set_restart_timeout()
{
    echo_green "${MASTER} Allowing ${1} min offline"
    ssh -o StrictHostKeyChecking=no "${MASTER}" -l splunk -- "/opt/splunk/bin/splunk edit cluster-config -restart_timeout ${1} -auth "${SPLK_USER}":${SPLK_PASS}"
}



# Main

echo_cyan "$dash_line"

enable_maintenancemode
echo_red "Reboot ClusterMaster"
for thishost in "${MASTER}" ; do
 	stop_splunk "${thishost}"
    go_reboot "${thishost}"
    wait_online_status "${thishost}" 60
done
disable_maintenancemode

set_restart_timeout 1200

echo_red "Reboot Indexers"
for thishost in "${INDEXERS[@]}" ; do
    enable_maintenancemode
    offline_splunk "${thishost}"
    go_reboot "${thishost}"
    wait_online_status "${thishost}" 120
    disable_maintenancemode
done

set_restart_timeout 600

echo_red "Reboot HF and SH"
for thishost in "${SHANDHF[@]}" ; do
    stop_splunk "${thishost}"
	go_reboot "${thishost}"
    wait_online_status "${thishost}" 10
done

echo_red "Reboot UF"
for thishost in "${UF[@]}" ; do
    stop_splunk "${thishost}"
	go_reboot "${thishost}"
done

echo_cyan "$dash_line"

# End
