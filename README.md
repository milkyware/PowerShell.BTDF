# PowerShell.BTDF

## Introduction

PowerShell.BTDF is a PowerShell module to work in conjunction with the BTDF packing framework.

It was inspired by the BizTalk ALM project (biztalkalm.codeplex.com) as I've used this before in automated builds and releases of BizTalk applications. These functions are designed to dynamically work out referenced applications and (re)deploy applications in the correct order to simply the deployment process

## Notes

### BTDF Project Requirements

Currently, these scripts rely on the "ProjectName" and "Manufacturer" properties being static values as BTDF uses these to create registry keys to store deployment configuration such as version number and deployment settings.

### Double-Hop

Using this module as part of a remote deployment in a multi-server BizTalk configuration (separate BizTalk and SQL servers) you will encounter issues with "double hop" authentication within PowerShell. A number of articles document this (blogs.technet.microsoft.com/heyscriptingguy/2013/04/04/enabling-multihop-remoting/), however, the commands needed are as follows:

For the server initiating the remote command (e.g. Deployment server)  
**Enable-WSManCredSSP –Role Client –DelegateComputer *server***  

For the server receiving the remote command (e.g. BizTalk server)  
**Enable-WSManCredSSP –Role Server**

The remote command then needs to pass authentication using **CredSSP** e.g.:  
**Invoke-Command -ComputerName *computer* ... -Credentials *creds* -Authentication CredSSP**