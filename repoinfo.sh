#!/bin/bash
log="/tmp/log_$HOSTNAME.txt"
echo "-------------------Starting at `date` ------------------" >$log
echo "---Setting repo path:" $1 >>$log
repo=$1 >>$log
echo "---Colleting the Folder Onwer/group:" >>$log
ls -l $repo >> $log
echo "---Colleting the service account:" >>$log 
ps axo user:20,pid,start,time,cmd | grep veeamtransport >>$log
echo "---Colleting information about SUDO:" >>$log 
veeamuser=`ps axo user:20,pid,start,time,cmd | grep "veeamtransport --run-service" | head -n1 | awk '{print $1;}'` 
sudo -l -U $veeamuser >>$log
echo "--Trying to collect information about listen ports - Part1:" >>$log
ss -lntu >>$log
echo "---Trying to collect information about listen ports - Part2:" >>$log
lsof -i >>$log
echo "---Trying to collect information about ssh service:" >>$log
ps aux | grep sshd >>$log
systemctl status sshd >>$log
systemctl status ssh >>$log
echo "---Trying to collet information about firewall service:" >>$log
sudo ufw status verbose >>$log
echo "-------------------Finishing at `date` ---------------" >>$log
echo "------------------------------"
echo "| Log Path:$log  |"    
echo "------------------------------"
exit 
