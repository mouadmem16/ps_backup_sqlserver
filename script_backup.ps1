param ($env, $SqlEngineName, $s3Bucket, $region, $serverInstance, $databases)


########################################################################### Help
$help = @"
# ------------ Don't forget to set the Aws Credtials in the PS Profile Type this command To do this
# `$AccessKey = "<Aceess Key>"
# `$SecretKey = "<Secret Key>"
# `$AwsCredName = "myAWScredentials"
# Set-AWSCredentials -AccessKey `$AccessKey -SecretKey `$SecretKey -StoreAs `$AwsCredName

# ------------ Information about the args
# -env: it is the environment of work, possible choice: prod, dev, test
# -SqlEngineName: it is the name of the database used, possible choice: db1, db2
# -s3Bucket: it is the name of the AWS S3 bucket
# -region: it is the region of your bucket
# -serverInstance: it's the server instance, like: "localhost\SQLEXPRESS"
# -databases: the name of the databases which you want to store, like @("dbtest", "dbtest1", "dbtest2")
"@

########################################################################### Params
$Date = Get-Date -UFormat "%Y-%m-%d-%H-%M" 
$AwsCredName = "myAWScredentials"



#$env = "test"
#$SqlEngineName = "db1"
#$s3Bucket = 'mouaad-mouadmem16-backup'
#$region = 'eu-west-3'
#$serverInstance = "localhost\SQLEXPRESS"
#Set-AWSCredentials $AwsCredName

if (($env -eq $null) -or ($SqlEngineName -eq $null) -or ($s3Bucket -eq $null) -or ($region -eq $null) -or ($serverInstance -eq $null) -or ($databases -eq $null)) {

	Write-Host $help -ForegroundColor Yellow

	Write-Host "$env, $SqlEngineName, $s3Bucket, $region, $serverInstance, $databases"

	throw "Fill all the arguments"

}

########################################################################### Preparing Env

New-Item -Path "C:\" -Name "tempSqlBackup" -ItemType "directory" -Force

$SqlBackup = "C:\tempSqlBackup\"

New-Item -Path $SqlBackup -Name "$Date-$env.log"

function Add-Log {
    param (
        $logMessage
    )

    $pathlogfile = $SqlBackup + "$Date-$env.log"

    Add-Content -Path $pathlogfile -Value "`r`n  ----------------  $(Get-Date -UFormat "%Y-%m-%d / %H:%M:%S")  ----------------  `r`n"
    Add-Content -Path $pathlogfile -Value $logMessage
}

function Upload-Log {
    param (
        $ErrorBool
    )

   	$s3Upload = @{
		BucketName = $s3Bucket
		Key = "$SqlEngineName/$env/logs/$Date-Succeed.log"
		File = $SqlBackup + "$Date-$env.log"
		Region = $region
		StoredCredentials = $AwsCredName
	}

    if( $ErrorBool ){ $s3Upload.Key = "$SqlEngineName/$env/logs/$Date-Failed.log" }
	Write-S3Object @s3Upload
	Remove-Item -LiteralPath $SqlBackup -Force -Recurse -Confirm:$false
}

############################################################################ Backup DBs except tempdb
Import-Module SQLPS


#Try {
#	$databases = Get-SqlDatabase -ServerInstance $serverInstance -ErrorAction Stop | Where { ($_.Name -ne 'tempdb') -and ($_.Name -ne 'master') } 
#	Add-Log "Connection to the instance {{ $serverInstance }} Succeed !! "
#} 
#Catch {
#    Add-Log "$($PSItem.Exception.Message) `r`n$($PSItem.Exception.StackTrace)"
#    Upload-Log $true
#    [Environment]::Exit(1)
#}

foreach($database in $databases){
	$dbName = $database.Name
	try{
		$backup = @{
			ServerInstance = $serverInstance
			Database = $dbName
			BackupFile = "$SqlBackup\$dbName.bak"
			#CompressionOption = On
		}
		Backup-SqlDatabase  @backup  #-Checksum
		Add-Log "Backup Database {{ $dbName }} Succeed !! "


		$compress = @{
		  Path = $backup.BackupFile
		  CompressionLevel = "Fastest"
		  DestinationPath = "$SqlBackup$Date-$dbName.zip"
		}
		Compress-Archive @compress
		Add-Log "Compression file {{ $($compress.DestinationPath) }} Succeed !! "


		$s3Upload = @{
			BucketName = $s3Bucket
			Key = "$SqlEngineName/$env/$Date-$dbName.zip"
			File = $compress.DestinationPath
			Region = $region
			StoredCredentials = $AwsCredName
		}
		Write-S3Object @s3Upload
		Add-Log "Upload file {{ $($s3Upload.File) }} to S3 bucket {{ $($s3Upload.BucketName) }} Succeed !! "

	}
	Catch {
	    Add-Log "$($PSItem.Exception.Message) `r`n$($PSItem.Exception.StackTrace)"
	    Upload-Log $true
	    [Environment]::Exit(1)
	}

}

Upload-Log $false
[Environment]::Exit(1)



#Remove-Module -Name SQLPS
# parquet format
# \env\db1\"%Y-%m-%d-%H-%M".zip
# instance profile
# $databases