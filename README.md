# Veeam Scripts
## This repository has some scripts to use with Veeam Products. If you are considering using these things, be aware that **you are doing so at your own risk.**



#########################  hardened-check.sh #############################################

The hardened-check.sh script was created to highlight possible configuration errors in the hardened repository, they are basic checks based on official Veeam guides:
Reference guides:

- https://helpcenter.veeam.com/docs/backup/vsphere/hardened_repository_deploy.html?ver=110

- https://www.veeam.com/wp-guide-protect-ransomware-immutable-backups.html?wpty

This script does not replace any type of hardened that you should apply in yours REPOs, for a more accurate hardened you should consult the your security team, in addition to the operating system vendor.

- Path: https://github.com/magnunscheffer/veeam/blob/main/hardened-check.sh

### To use it, is necessary load to the repository server and run the follow steps:
- Grant execution permission to the script:

  *chmod +x /path/hardened-check.sh*

- Run the script passing the Repo path as a parameter, like this /hardened-check.sh repo-path, Example:
 
  *./hardened-check.sh /mnt/repo001/backups*

Result Samples:

![alt text](https://github.com/magnunscheffer/veeam/blob/main/output-example-1.jpg?raw=true)


![alt text](https://github.com/magnunscheffer/veeam/blob/main/output-example-2.jpg?raw=true)

#########################  hardened-check.sh #############################################

