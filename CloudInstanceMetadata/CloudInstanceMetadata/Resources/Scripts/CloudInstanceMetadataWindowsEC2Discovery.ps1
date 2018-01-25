# CloudInstanceMetadataWindowsEC2Discovery.ps1
[cmdletbinding()]
Param(
	$ForceEC2 = $false,
	[string]
	$PrincipalName
)

# Global

$ForceEC2 = [bool]::Parse($ForceEC2)
$ScomAPI = New-Object -ComObject "MOM.ScriptAPI"
$discoveryData = $ScomAPI.CreateDiscoveryData(0,'$MPElement$','$Target/Id$')

function Log-SCOMMessage {
	Param(
		[string]
		$message
	)

	$ScomAPI.LogScriptEvent("CloudInstanceMetadataWindowsEC2Discovery.ps1", 6459, 0, $message)
}

Log-SCOMMessage -message "Script starting up"

# Test if AWS agent is running or BIOS and Manufacturer indicate Amazon
$awsAgentPresent = $null -ne (Get-Service -Name AWSLiteAgent -ErrorAction SilentlyContinue)
$computerProduct = (Get-WmiObject -Class Win32_ComputerSystemProduct)
$isAmazonVM = $computerProduct.Version -match '\.amazon$'

if ($ForceEC2 -or $awsAgentPresent -or $isAmazonVM) {

	Log-SCOMMessage -message "BIOS, running agents, or discovery override indicate we should try and contact the metadata service"
	# Attempt to contact Instance metadata

	$webParams = @{
		'Method'='Get' 
		'TimeoutSec'= 1
		'UseBasicParsing'=$true
		'ErrorAction'= 'SilentlyContinue'
	}

	
	Try {
		$response = Invoke-webrequest  -URI 'http://169.254.169.254/latest/dynamic/instance-identity/document' @webParams 
		if ($response.statusCode -eq 200){
			Log-SCOMMessage -message "Processing instance metadata"
			# Create discovery data
			$metadata = $response.content | ConvertFrom-Json

			$vm = $discoveryData.CreateClassInstance('$MPElement[Name="CloudInstanceMetadata.Class.IaaSVM.AWSEC2.Windows"]$')
			$vm.AddProperty('$MPElement[Name="Windows!Microsoft.Windows.Computer"]/PrincipalName$', $PrincipalName)
			$vm.AddProperty('$MPElement[Name="System!System.Entity"]/DisplayName$', "AWS EC2 VM ($([environment]::MachineName))")
			$vm.AddProperty('$MPElement[Name="CloudInstanceMetadata.Class.IaaSVM"]/Id$',$metadata.instanceId)

			# Multiple Public and Private IPs possible based on schema

			$publicIPv4 = @()
			$privateIPv4 = @()
			$publicHostname = @()
			$localHostname = @()

			$interfaceUrl = 'http://169.254.169.254/latest/meta-data/network/interfaces/macs/'
			$interfaceMacs = (Invoke-WebRequest -Uri $interfaceUrl @webParams).Content

			foreach ($interface in $interfaceMacs.Split("`n")) {

				$private = (Invoke-WebRequest -Uri "$($interfaceUrl)$($interface)local-ipv4s" @webParams).Content
				
				foreach ($ip in $private.Split("`n")) {
					if (-not [string]::IsNullOrEmpty($ip)) {
						$privateIPv4 += $ip
					}
				}

				$public = (Invoke-WebRequest -Uri "$($interfaceUrl)$($interface)public-ipv4s" @webParams).Content

				foreach ($ip in $public.Split("`n")) {
					if (-not [string]::IsNullOrEmpty($ip)) {
						$publicIPv4 += $ip
					}
				}

				$pHostname = (Invoke-WebRequest -Uri "$($interfaceUrl)$($interface)public-hostname" @webParams).Content
				foreach ($name in $pHostname.Split("`n")) {
					if (-not [string]::IsNullOrEmpty($name)) {
						$publicHostname += $name
					}
				}

				$lHostname = (Invoke-WebRequest -Uri "$($interfaceUrl)$($interface)local-hostname" @webParams).Content
				foreach ($name in $lHostname.Split("`n")) {
					if (-not [string]::IsNullOrEmpty($name)) {
						$localHostname += $name
					}
				}
			}

			$vm.AddProperty('$MPElement[Name="CloudInstanceMetadata.Class.IaaSVM"]/PublicIPv4$', [string]::Join(", ", $publicIPv4))
			$vm.AddProperty('$MPElement[Name="CloudInstanceMetadata.Class.IaaSVM"]/PrivateIPv4$', [string]::Join(", ", $privateIPv4))
			$vm.AddProperty('$MPElement[Name="CloudInstanceMetadata.Class.IaaSVM.AWSEC2"]/PublicHostname$', [string]::Join(", ", $publicHostname))
			$vm.AddProperty('$MPElement[Name="CloudInstanceMetadata.Class.IaaSVM.AWSEC2"]/PrivateHostname$', [string]::Join(", ", $localHostname))
			$vm.AddProperty('$MPElement[Name="CloudInstanceMetadata.Class.IaaSVM.AWSEC2"]/AvailabilityZone$', $metadata.availabilityZone)
			$vm.AddProperty('$MPElement[Name="CloudInstanceMetadata.Class.IaaSVM.AWSEC2"]/AccountId$', $metadata.accountId)
			$vm.AddProperty('$MPElement[Name="CloudInstanceMetadata.Class.IaaSVM.AWSEC2"]/InstanceType$', $metadata.instanceType)
			$vm.AddProperty('$MPElement[Name="CloudInstanceMetadata.Class.IaaSVM.AWSEC2"]/ImageId$', $metadata.imageId)
			$vm.AddProperty('$MPElement[Name="CloudInstanceMetadata.Class.IaaSVM.AWSEC2"]/Region$', $metadata.region)

			$securityGroups = (Invoke-WebRequest -Uri 'http://169.254.169.254/latest/meta-data/security-groups' @webParams).Content
			$vm.AddProperty('$MPElement[Name="CloudInstanceMetadata.Class.IaaSVM.AWSEC2"]/SecurityGroups$', $securityGroups.Replace("`n",', '))
			
			$discoveryData.AddInstance($vm)

		}
		else {
			Log-SCOMMessage -message "$($response.statusCode) Response returned attempting to contact instance metadata service."
		}
		
	} catch {
		Log-SCOMMessage -message "Instance metadata servcie not available.  Error message is:`n $($_.Exception)"
	}
}

# Return discovery data to SCOM
$discoveryData
Log-SCOMMessage -message "Discovery complete."
