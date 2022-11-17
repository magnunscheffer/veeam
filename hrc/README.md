
# hardened-check.sh 

The hardened-check.sh script was created to highlight possible configuration errors in the hardened repository, they are basic checks based on official Veeam guides:
Reference guides:

- https://helpcenter.veeam.com/docs/backup/vsphere/hardened_repository_deploy.html?ver=110

- https://www.veeam.com/wp-guide-protect-ransomware-immutable-backups.html?wpty

This script does not replace any type of hardened that you should apply in yours REPOs, for a more accurate hardened you should consult the your security team, in addition to the operating system vendor.

- Path: https://github.com/magnunscheffer/veeam/blob/main/hrc/hr-check.sh

## To use it, do:
- Download and Grant execution permission to the script:

```bash
curl -O https://raw.githubusercontent.com/magnunscheffer/veeam/main/hrc/hr-check.sh && chmod +x hardened-check.sh
```
- Example with short url:
```bash
curl -O https://vee.am/hr-check.sh && chmod +x hardened-check.sh
```

- Run the script passing the Repo path as a parameter, like this example:
 
```bash
./hardened-check.sh /mnt/repo01/backups
```




Result Samples:

![alt text](https://github.com/magnunscheffer/veeam/blob/main/output-example-1.jpg?raw=true)


![alt text](https://github.com/magnunscheffer/veeam/blob/main/output-example-2.jpg?raw=true)

#########################  hardened-check.sh #############################################

