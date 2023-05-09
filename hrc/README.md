
# Hardened Repository Check

The hr-check.sh script was created to highlight possible configuration errors in the hardened repository, they are basic checks based on official Veeam guides:

- https://helpcenter.veeam.com/docs/backup/vsphere/hardened_repository.html?ver=120

- https://www.veeam.com/wp-guide-protect-ransomware-immutable-backups.html?wpty

This script does not replace any type of hardened that you should apply in yours REPOs, for a more accurate hardened you should consult the your security team, in addition to the operating system vendor.

- Path: https://github.com/magnunscheffer/veeam/blob/main/hrc/hr-check.sh

## How to:
- Download and grant execute permission to the script directly on the repository server:

```bash
curl -O https://raw.githubusercontent.com/magnunscheffer/veeam/main/hrc/hr-check.sh && chmod +x hr-check.sh
```
Example with short url:
```bash
curl -OL --max-redirs 5 https://vee.am/hrc22 && mv hrc22 hr-check.sh  && chmod +x hr-check.sh
```

- Run the script passing the Repo path as a parameter, like this example:
 
```bash
./hr-check.sh /mnt/repo01/backups
```


### Download & Run example:
![alt text](https://github.com/magnunscheffer/veeam/blob/main/hrc/download-example.png?raw=true)


-----------------------------------------------------------------

### Result Example:

![alt text](https://github.com/magnunscheffer/veeam/blob/main/hrc/run-example1.png?raw=true)
