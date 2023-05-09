#!/bin/bash


#Autor: Magnun Scheffer | Contact: mfs_@outlook.com
#Version: 0.3
#Download: 'curl -O https://raw.githubusercontent.com/magnunscheffer/veeam/main/hrc/hr-check.sh && chmod +x hr-check.sh'
#Alternative: 'curl -OL --max-redirs 5 https://vee.am/hrc22 && mv hrc22 hr-check.sh  && chmod +x hr-check.sh'
#Run: './hr-check.sh /mnt/repo01/backups'
# The parameter '/mnt/repo01/backups' is the folder visible on VBR console --> Backup Infrastructure --> Backup Repositories --> Path
#Disclaimer:If you are considering using this script, be aware that you are doing so at your own risk.
#Plataform tested: RedHat/CentOS 7 & 8 / Ubuntu 20.04


#Configuring terminal colors
terminalColorClear='\033[0m'
terminalColorInfo='\033[0;32m'
terminalColorWarning='\033[0;33m' 
terminalColorBanner='\033[0;41m'
#Regular Color
echoD() {
    echo -e "${terminalColorClear}$1${terminalColorClear}"
} 
#Information Color (Green)
echoI() {
    echo -e "${terminalColorInfo}$1${terminalColorClear}"
}
#Warning Color (Orange)
 echoW() {
    echo -e "${terminalColorWarning}$1${terminalColorClear}"
}
#Banner Color (Red)
 echoB() {
    echo -e "${terminalColorBanner}$1${terminalColorClear}"
} 

#Log Path under construction... 
log="Log-$HOSTNAME-$(date +%d%m%Y_%H%M%S).txt"


#Defaul Status for terms.
terms="N"
nl=$'\n'
output=$(cat <<-EOF
-----------------------------------------------------------------------------------------------------------------------------------------------
|This script is independently produced and has no direct link to Veeam Software. It just checks the recommendations related to the user guide |
|article and Veeam Write Paper *Protect against Ransomware with Immutable Backups*:                                                           |
|- https://helpcenter.veeam.com/docs/backup/vsphere/hardened_repository.html?ver=120                                                          |
|- https://www.veeam.com/wp-guide-protect-ransomware-immutable-backups.html                                                                   |
|                                                                                                                                             |
|By using this script you are at your own risk. Do you accept these terms? [YES=Y or NO=N]:                                                   |
-----------------------------------------------------------------------------------------------------------------------------------------------
EOF
)
echoB "$output" && echo -e "$output" > $log  
read input

#converting to CAPITAL
terms=${input^^}

#Populating the log with terms information.
echo -e "INPUT='$terms'" >> $log

#Testing if the terms were accepted.
if [ "$terms" != "Y" ] 
then
    output="You didn't accept the terms!. Input 'Y' to accept the terms, ending the script now ..."
    echoI "$output" && echo -e "$output" >> $log  
    exit
fi

#Start of script
output="\n-------------------Starting at $(date) ------------------\n
- Repository path: $1 ..."
repo=$1 
echoD "$output" && echo -e "$output" >> $log

#Looking for Ubuntu, because the diferent name of SSH service and firewall...
distr=$(uname -a | grep -o Ubuntu)
if [ -z "$distr" ]
then #others_distr	   
   service="sshd"
   fwstate=$(firewall-cmd --state 2>&1)
   fwconfig="firewall-cmd --list-all"
   permok="drwx------."
   echo -e "\n- Is a Ubuntu Distro?\n   NO | Distr: $(uname -a)" >> $log
else #ubuntu   
   service="ssh"
   fwstate=$(sudo ufw status verbose | grep -oP '(?<=Status: )[^ ]*')
   fwconfig="sudo ufw status verbose | grep Action -A 999999"
   permok="drwx------"		
   echo -e "\n- Is a Ubuntu Distro?\n   YES | Distr: $(uname -a)" >> $log
fi
output="\n- Checking the veeamtransport service user and folder owner for '$repo'..."
echoD "$output" && echo -e "$output" >> $log

#Geting information about service account. 
svcuser=$(ps axo user:20,pid,start,time,cmd | grep "veeamtransport --run-service" | grep -v grep |  head -n1 | awk '{print $1;}')
#echo -e "ServiceUser: $svcuser" >> $log #enable for debug only

#Geting information about dir owner. 
dirowner=$(ls -ld $repo | awk '{print $3}')
#echo -e "DirOwner: $dirowner" >> $log #enable for debug only

#Testing if the dir owner is correct.
#Testing if Service Account is not Root.
if [ "$svcuser" == "root" ]
then
    output="
    Warning: Please do not use the 'root' user as a service account for the 'veeamtransport' service!
    Use a 'normal' user with temporary SUDO permissions for this.

    More details:	
    https://helpcenter.veeam.com/docs/backup/vsphere/hardened_repo_specify_server.html?ver=120
    Reference: 'The user account you specified must be a non-root account. Also, it must have the home directory created on the Linux server.'\n
    https://helpcenter.veeam.com/docs/backup/vsphere/hardened_repository.html?zoom_highlight=single+use+Credentials&ver=120
    Reference: 'Single-use credentials: credentials that are used only once to deploy Veeam Data Mover, or transport service, while adding the Linux server to the backup infrastructure. These credentials are not stored in the backup infrastructure.
    Even if the Veeam Backup & Replication server is compromised, the attacker cannot get the credentials and connect to the hardened repository.'"

    echoW "$output" && echo -e "$output" >> $log
else 
    if [ "$dirowner" == "$svcuser" ]
    then 
        output="
    Info: The service user '$svcuser' and the dir owner '$dirowner' are the same!\n
    More details:
    https://helpcenter.veeam.com/docs/backup/vsphere/hardened_repository_prepare.html?ver=120
    Reference: 'Both owner and group can be the account that you plan to use to connect to the Linux server.'"
        echoI "$output" && echo -e "$output" >> $log	
    else 
        output="
    Warning: The user: $svcuser is different from the folder owner: $dirowner !. Please ensure that the user configured in the folder is the same as the one. configured in the veeam console.\n
    More details:
    https://helpcenter.veeam.com/docs/backup/vsphere/hardened_repository_prepare.html?ver=120
    Reference: 'Both owner and group must be the account you use to connect to the Linux server' 
    https://helpcenter.veeam.com/docs/backup/vsphere/hardened_repo_launch_wizard.html?ver=120
    To fix that: 'In the Add Backup Repository window, select Direct attached storage > Linux (Hardened Repository).'"
        echoW "$output" && echo -e "$output" >> $log	
    fi
fi

output="\n- Checking the folder permissions for '$repo' ..."
echoD "$output" && echo -e "$output" >> $log	

#Geting information about the permissions.
permission=$(ls -ld $repo | awk '{print $1}')
echo -e $permission >> $log #enable for debug only

#Comparing the permissions with the right value: 700.
if [ "$permission" == "$permok" ]
then 
    output="
    Info: The repository '$repo' is configured with the correct permission '$permission'(700)

    More details:
    https://helpcenter.veeam.com/docs/backup/vsphere/hardened_repository_deploy.html?ver=110#step-1--prepare-directory-on-linux-server-for-backups
    Reference: 'To allow access to the folder only for its owner and root account: chmod 700 <folder_path>'"
    echoI "$output" && echo -e "$output" >> $log	
else 
    output="
    Warning: Permission of repository '$repo' is wrong! ($permission), please set it to '$permok'(Ex: 'chmod 700 $repo')!

    More details:
    https://helpcenter.veeam.com/docs/backup/vsphere/hardened_repository_prepare.html?ver=120    
    Reference: 'To allow access to the folder only for its owner and root account: chmod 700 <folder_path>'"
    echoW "$output" && echo -e "$output" >> $log
fi
output="\n- Checking the SUDO rights ..."
echoD "$output" && echo -e "$output" >> $log	
 
#Default message for a user without SUDO rights. 
messagenosudo=`echo "User $svcuser is not allowed to run sudo on $HOSTNAME."`

#Geting info about sudo for the service user account.
sudoresult=$(sudo -l -U $svcuser)

#Comparing with the no sudo message.
if [ "$sudoresult" == "$messagenosudo" ]
then 
    output="
    Info: The user $svcuser doesn't have SUDO access, this is a good practice!

    More details:
    https://helpcenter.veeam.com/docs/backup/vsphere/hardened_repo_specify_server.html?ver=120
    Reference: 'If you added the user account to the sudoers file, you do not need to select the Use "su" if "sudo" fails check box and specify the root password. But after the server is added, you must remove the user account from the file.'"
    echoI "$output" && echo -e "$output" >> $log
else 
    output="
    Warning: Possible security breach!, user: $svcuser has SUDO rights, please disable the SUDO!

    More details:      
    https://helpcenter.veeam.com/docs/backup/vsphere/hardened_repository_deploy.html?ver=110#step-2--add-linux-server-to-backup-infrastructure
    Reference: 'After the user will have temporary root- or sudo-permissions you must remove the user from the sudo group after the server is added.'"
    echoW "$output" && echo -e "$output" >> $log
fi

output="\n- Cheking the LISTEN ports ...\n    --------------------------------------------------------------------------------"
echoD "$output" && echo -e "$output" >> $log

#Geting all ports in listen mode, except for the loopback.    
array=($(ss -lntu | grep LISTEN | grep -v 127.0.0 | awk '{print $5} ' | sed 's/.*://' | sort | uniq))

#Testing each port if is a veeam port
for i in "${array[@]}"
do
   : 
   #Testing each port if is a veeam port
   if ([ $i -lt 2500 ] || [ $i -gt 3300 ] && [ $i != "6160" ] && [ $i != "6162" ] )
   then
	output="\n    Warning: $i is not a veeam service port, please disable it!"
	echoW "$output" && echo -e "$output" >> $log
   else 
	output="\n    Info: $i is a veeam service/transport port."
	echoI "$output" && echo -e "$output" >> $log
   fi
done

output="\n    --------------------------------------------------------------------------------\n
    More details:
    https://www.veeam.com/wp-guide-protect-ransomware-immutable-backups.html

    Reference: (Page 17): '8. Only run the Veeam transport service available on the network (SSH can be an exception).           
    There should especially be no third-party network services running with root permissions.                                   
    If an attacker can gain root access via a third-party software on the Hardened Repository, then they can delete all data.'"

echoD "$output" && echo -e "$output" >> $log

output="\n- Cheking the SSH Service status ..."
echoD "$output" && echo -e "$output" >> $log


#Testing SSH Service status
sshstatus=`systemctl status $service | grep running`

if [ -z "$sshstatus" ]
then
    output="\n    Info: SSH service is not running, this is a good practice!

    More details:
    https://www.veeam.com/wp-guide-protect-ransomware-immutable-backups.html                                                    
    Reference: (Page 17): '6. Secure access to the operating system. Use state-of-the-art multi-factor authentication. 
    If acceptable, disable the SSH Server completely and leave server access to the local physical console alone'"
    echoI "$output" && echo -e "$output" >> $log	
   
else 
    output="\n    Warning: Is not recommended keep SSH service enabled in Veeam Hardened Repository!, please disable it!\n
    Service Status: $sshstatus\n	

    More details:
    https://www.veeam.com/wp-guide-protect-ransomware-immutable-backups.html                                                    
    Reference: (Page 17): '6. Secure access to the operating system. Use state-of-the-art multi-factor authentication. 
    If acceptable, disable the SSH Server completely and leave server access to the local physical console alone'"	
    echoW "$output" && echo -e "$output" >> $log

fi

output="\n- Cheking the Firewall status.... $fwstate"
echoD "$output" && echo -e "$output" >> $log

#Testing if the FW is enable.
if [ "$fwstate" == "active" ] || [ "$fwstate" == "running" ]
then
   output="\n   Info: The firewall is enabled, but remember that only veeam service ports should be kept open: [6162, 2500-3300].

   More details:
   https://www.veeam.com/wp-guide-protect-ransomware-immutable-backups.html                                                    
   Reference: (Page 8): 'During installation, Veeam configures the Linux firewall and allows incoming traffic to port 6162. 
   Iptables rules for dynamic ports (2500–3300 per default) are configured automatically during the job run. 
   All these firewall rules are removed automatically after the job finishes execution'\n

   Current firewall rules:\n
   --------------------------------------------------------------------------------\n"
   echoI "$output" && echo -e "$output" >> $log
   $fwconfig && $fwconfig >> $log
else
   output="\n   Warning: Please enable Firewall and keep only veeam ports allowed [6162, 2500-3000]!

   More details:
   https://www.veeam.com/wp-guide-protect-ransomware-immutable-backups.html                                                    
   Reference: (Page 8): 'During installation, Veeam configures the Linux firewall and allows incoming traffic to port 6162. 
   Iptables rules for dynamic ports (2500–3300 per default) are configured automatically during the job run. 
   All these firewall rules are removed automatically after the job finishes execution'"
   echoW "$output" && echo -e "$output" >> $log
fi

logpath="$(pwd)/$log"
output="-------------------Finishing at $(date) --------------- Log file:$logpath"
echoD "$output" && echo -e "$output" >> $log
