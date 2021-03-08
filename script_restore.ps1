
$SqlBackup = "C:\"

$s3Bucket = '<name>' # ← - - - Specify the Name of your S3 bucket
$region = '<region>' # ← - - - Specify the Region of your S3 bucket
$AwsCredName = "myAWScredentials" 
$AccessKey = "<acesskey>" # ← - - - Specify the Access Key of the AWS account
$SecretKey = "<secretkey>" # ← - - - Specify the Secret Key of the AWS account

#Set-AWSCredentials -AccessKey $AccessKey -SecretKey $SecretKey -StoreAs $AwsCredName

Set-AWSCredentials $AwsCredName


$s3Object =  Get-S3Object -StoredCredentials $AwsCredName -BucketName $s3Bucket -Region $region | Sort-Object LastModified -Descending | Select-Object -First 1

$filezip = $SqlBackup + $s3Object.key

$Params = @{
	BucketName = $s3Bucket
	Key = $s3Object.Key
	File = $filezip
	Region = $region
	StoredCredentials = $AwsCredName
}

Read-S3Object @Params

expand-archive -path $filezip -DestinationPath $SqlBackup

Remove-Item $filezip

#################################################################################################
Import-Module SQLPS

$SqlBackup = "C:\tempSqlBackup\"
$serverInstance = "localhost\SQLEXPRESS"  # ← - - - Specify the Instance Name

$backupFiles = Get-ChildItem -Path $SqlBackup
forEach($backupfile in $backupFiles){ 
	$dbName = $backupfile.BaseName
	$backupFile = $SqlBackup + $dbName + ".bak"
	Restore-SqlDatabase -ServerInstance $serverInstance -Database $dbName -BackupFile $backupFile
}

Remove-Item -LiteralPath $SqlBackup -Force -Recurse -Confirm:$false

