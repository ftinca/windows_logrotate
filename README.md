# Windows Logrotate

A simple log rotation script for Windows that automates log file management using PowerShell.

## Prerequisites

- **PowerShell** version 5.0 or higher.

## Deployment and Configuration

Follow these steps to deploy and configure the log rotation system.

### 1. Create Necessary Directory

Run the following command in PowerShell **as Administrator** to create the required directory:

```powershell
New-Item -ItemType Directory -Path "C:\ScheduledTasks\LogRotate" -Force
```

### 2. Save logrotate.ps1 at 
``C:\Scripts\ScheduledTasks\LogRotate\logrotate.ps1``

### 3. Save conf.json file at and edit it as necessary
``C:\Scripts\ScheduledTasks\LogRotate\conf.json``

### 4. Run the following command as Administrator. 
This will create a Scheduled Task that runs every day at 11:30 PM machine time. (edit the time as necessary)
```powershell
schtasks /create /tn "LogRotateTask" /tr "powershell.exe -File 'C:\ScheduledTasks\LogRotate\logrotate.ps1'" /sc daily /st 23:30 /ru "SYSTEM" /rl HIGHEST /f
```
