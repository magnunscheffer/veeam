#!/bin/bash
log="/tmp/log_$HOSTNAME.txt"
echo "-------------------Starting at `date` ------------------" >$log
echo "---Setting repo path:" $1 >>$log 2>&1
repo=$1 >>$log 2>&1
echo "---Colleting the Folder Onwer/group:" >>$log 2>&1
ls -ld $repo >>$log 2>&1
echo "---Colleting the service account:" >>$log 2>&1 
ps axo user:20,pid,start,time,cmd | grep veeamtransport >>$log 2>&1
echo "---Colleting information about SUDO:" >>$log 2>&1 
veeamuser=`ps axo user:20,pid,start,time,cmd | grep "veeamtransport --run-service" | head -n1 | awk '{print $1;}'` 
sudo -l -U $veeamuser >>$log 2>&1
echo "--Trying to collect information about listen ports - Part1:" >>$log 2>&1
ss -lntu >>$log 2>&1
echo "---Trying to collect information about listen ports - Part2:" >>$log 2>&1
lsof -i -n -P >>$log 2>&1
echo "---Trying to collect information about ssh service:" >>$log 2>&1
ps aux | grep sshd >>$log 2>&1
systemctl status sshd >>$log 2>&1
echo "---Trying to collet information about firewall service:" >>$log 2>&1
firewall-cmd --state >>$log 2>&1 2>&1
firewall-cmd --list-all >>$log 2>&1
echo "-------------------Finishing at `date` ---------------" >>$log 2>&1
echo "------------------------------"
echo "| Log Path:$log  |"    
echo "------------------------------"
exit 
