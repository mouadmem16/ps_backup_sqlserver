########################################################################### Preparing Env

New-Item -Path "C:\" -Name "tempSqlBackup" -ItemType "directory" -Force
New-Item -Path "C:\" -Name "tempSqlZip" -ItemType "directory" -Force

$SqlBackup = "C:\tempSqlBackup\"
$SqlZip = "C:\tempSqlZip\"

############################################################################ Backup DBs except tempdb
Import-Module SQLPS

$serverInstance = "localhost\SQLEXPRESS" # ← - - - Specify the Instance Name

$databases = Get-SqlDatabase -ServerInstance $serverInstance | Where { ($_.Name -ne 'tempdb') -and ($_.Name -ne 'master') }

foreach($database in $databases){ 
	$dbName = $database.Name
	Backup-SqlDatabase -ServerInstance $serverInstance -Database "$dbName" -BackupFile "$SqlBackup\$dbName.bak" #-CompressionOption On -Checksum
}

#Remove-Module -Name SQLPS
#############################################################################

$DT = Get-Date -UFormat "%Y-%m-%d-%H-%M"
compress-archive -path $SqlBackup -destinationpath "$SqlZip\backup-$DT.zip" -compressionlevel optimal

Remove-Item -LiteralPath $SqlBackup -Force -Recurse -Confirm:$false

############################################################################# S3

$s3Bucket = '<name>' # ← - - - Specify the Name of your S3 bucket
$region = '<region>' # ← - - - Specify the Region of your S3 bucket
$AwsCredName = "myAWScredentials" 
$AccessKey = "<acesskey>" # ← - - - Specify the Access Key of the AWS account
$SecretKey = "<secretkey>" # ← - - - Specify the Secret Key of the AWS account

#Set-AWSCredentials -AccessKey $AccessKey -SecretKey $SecretKey -StoreAs $AwsCredName

Set-AWSCredentials $AwsCredName

Write-S3Object -BucketName $s3Bucket -StoredCredentials $AwsCredName -File "$SqlZip\backup-$DT.zip" -Region $region

Remove-Item -LiteralPath $SqlZip -Force -Recurse -Confirm:$false

