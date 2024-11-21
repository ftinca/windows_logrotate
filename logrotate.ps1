# Path to the configuration file
$baseDir = "C:\ScheduledTasks\logrotate"
$configFilePath = "$baseDir\conf.json"
$logrotateLogDirPath = "$baseDir\logs"


# Check if the configuration file exists
if (-not (Test-Path $configFilePath)) {
    Write-Output "Configuration file not found: $configFilePath"
    exit 1
}


# Check if PowerShell version is greater than or equal to 5.0, exit otherwise.
if ($PSVersionTable.PSVersion -lt [Version]"5.0") {
    Write-Output "This script requires PowerShell version 5.0 or greater."
    exit 1
}

if (-not (Test-Path $logrotateLogDirPath)) {
    try {
        New-Item -ItemType Directory -Path $logrotateLogDirPath -ErrorAction Stop
        Write-Output " [INFO] Created log rotation directory: $logrotateLogDirPath"
    } catch {
        Write-Output " [ERROR] Error creating log rotation directory: $_"
        exit 1
    }
}

# Function to log messages
function Log-Message {
    param (
        [string]$message,
        [string]$logrotateLogDirPath,
        [int]$maxLogSizeMB
    )
     # Ensure the log directory exists
    $logFilePath = "$logrotateLogDirPath\logrotate.log"
    if (-not (Test-Path $logFilePath)) {
        try {
            # Create the log file
            New-Item -ItemType File -Path $logFilePath -Force -ErrorAction Stop
            Write-Output " [INFO] Created log file: $logFilePath"
        } catch {
            Write-Output " [ERROR] Error creating log file: $_"
            exit 1
        }
    }
    # Check the size of the log file and truncate if necessary
    $logFileSize = [math]::Round((Get-Item $logFilePath).Length / 1MB, 2)
    if ($logFileSize -gt $maxLogSizeMB) {
        Write-Output " [WARN] Log file size exceeds $maxLogSizeMB MB. Truncating the log file."
        Clear-Content -Path $logFilePath -ErrorAction Stop
        Add-Content -Path $logFilePath -Value " [INFO] $timestamp - Log file was truncated due to exceeding the size limit of $maxLogSizeMB MB."
    }
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $logFilePath -Value "$timestamp - $message"
}

# Load configuration from the JSON file
$configs = Get-Content -Path $configFilePath | ConvertFrom-Json
$maxLogSizeMB = $configs.MaxLogSizeMB

# Process each configuration set
foreach ($config in $configs.Config) {
     $logPath = $config.LogPath
     # Continue only if path exists.
     if ( Test-Path $logPath ) {
        Log-Message " [INFO] Processing log rotation for path: $logPath" $logrotateLogDirPath $maxLogSizeMB
        $compressionDays = $config.CompressionDays
        $deletionDays = $config.DeletionDays
  
        # Define derived paths
        $archivePath = "$logPath\Archive"
    
        # Ensure the archive directory exists
        if (-not (Test-Path $archivePath)) {
            try {
                New-Item -ItemType Directory -Path $archivePath -ErrorAction Stop
                Log-Message " [INFO] Created archive directory: $archivePath" $logrotateLogDirPath $maxLogSizeMB
            } catch {
                Log-Message " [ERROR] Error creating archive directory: $_" $logrotateLogDirPath $maxLogSizeMB
                exit 1
            }
        }
    
        # Get the current date
        $currentDate = Get-Date
        
        # Delete log files older than $deletionDays days
        $filesToDelete = Get-ChildItem -Path $logPath -Filter *.log | Where-Object { $_.LastWriteTime -lt $currentDate.AddDays(-$deletionDays) }
    
        foreach ($file in $filesToDelete) {
            try {
                Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                Log-Message "$($file.FullName) is older that $deletionDays days and was deleted." $logrotateLogDirPath $maxLogSizeMB
            } catch {
                Log-Message " [ERROR] Error deleting file $($file.FullName): $_" $logrotateLogDirPath $maxLogSizeMB
            }
        }
        
        # Compress log files older than $compressionDays days
        $filesToCompress = Get-ChildItem -Path $logPath -File | Where-Object { $_.LastWriteTime -lt $currentDate.AddDays(-$compressionDays) }
    
        foreach ($file in $filesToCompress) {
            $originalLastWriteTime = $file.LastWriteTime # Store the original last write time
            $tempFile = "$archivePath\$($file.BaseName).log"
            $compressedFile = "$archivePath\$($file.BaseName).zip"
    
            try {
                # Move the log file to the archive directory
                Move-Item -Path $file.FullName -Destination $tempFile -Force -ErrorAction Stop
                Log-Message "Moved file $($file.FullName) to $tempFile" $logrotateLogDirPath $maxLogSizeMB
    
                # Compress the log file
                Compress-Archive -Path $tempFile -DestinationPath $compressedFile -ErrorAction Stop
                Log-Message "Compressed file $tempFile to $compressedFile" $logrotateLogDirPath $maxLogSizeMB
    
                # Set the original last write time on the compressed file
                Set-ItemProperty -Path $compressedFile -Name LastWriteTime -Value $originalLastWriteTime
                Log-Message "Set last modified time of $compressedFile to $originalLastWriteTime" $logrotateLogDirPath $maxLogSizeMB
    
                # Remove the original log file after compression
                Remove-Item -Path $tempFile -Force -ErrorAction Stop
                Log-Message "Removed original log file $tempFile" $logrotateLogDirPath $maxLogSizeMB
                
            } catch {
                Log-Message " [ERROR] Error processing file $($file.FullName): $_" $logrotateLogDirPath $maxLogSizeMB
            }
        }
    
        # Delete compressed files older than $deletionDays days
        $compressedFilesToDelete = Get-ChildItem -Path $archivePath -Filter *.zip | Where-Object { $_.LastWriteTime -lt $currentDate.AddDays(-$deletionDays) }
    
        foreach ($file in $compressedFilesToDelete) {
            try {
                Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                Log-Message "$($file.FullName) is older that $deletionDays days and was deleted." $logrotateLogDirPath $maxLogSizeMB
            } catch {
                Log-Message " [ERROR] Error deleting file $($file.FullName): $_" $logrotateLogDirPath $maxLogSizeMB
            }
        }
        Log-Message " [INFO] Log rotation completed for path: $logPath" $logrotateLogDirPath $maxLogSizeMB
    }
    else {
        Log-Message " [WARN] Path does not exist: $logPath" $logrotateLogDirPath $maxLogSizeMB
    }
}
