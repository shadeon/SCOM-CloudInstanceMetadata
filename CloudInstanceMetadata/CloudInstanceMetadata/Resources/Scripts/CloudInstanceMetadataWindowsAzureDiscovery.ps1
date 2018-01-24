# CloudInstanceMetadataWindowsAzureDiscovery.ps1
[cmdletbinding()]
Param(
	$ForceAzure = $false,
	[string]
	$PrincipalName
)

# Global

$ForceAzure = [bool]::Parse($ForceAzure)
$ScomAPI = New-Object -ComObject "MOM.ScriptAPI"
$discoveryData = $ScomAPI.CreateDiscoveryData(0,'$MPElement$','$Target/Id$')

# Test if Azure agent is running or BIOS and Manufacturer indicate MS VM
$azureAgentPresent = $null -eq (Get-Service -Name WindowsAzureGuestAgent -ErrorAction SilentlyContinue)
$computerProduct = (Get-WmiObject -Class Win32_ComputerSystemProduct)
$isMicrosoftVM = $computerProduct.Vendor -eq 'Microsoft Corporation' -and $computerProduct.Name -eq 'Virtual Machine'

if ($ForceAzure -or $azureAgentPresent -or $isMicrosoftVM) {

	# Attempt to contact Instance metadata
	Try {
		$response = Invoke-webrequest -Headers @{"Metadata"="true"} -URI 'http://169.254.169.254/metadata/instance?api-version=2017-08-01' -Method get -TimeoutSec 1 -ErrorAction SilentlyContinue
		if ($response.statusCode -eq 200){
			# Create discovery data
			$metadata = $response.content | ConvertFrom-Json

			$id = $metadata.compute.vmId
			if (-not $id) {
				$id = $computerProduct.UUID.ToLower()
			}
			
			$vm = $discoveryData.CreateClassInstance('$MPElement[Name="CloudInstanceMetadata.Class.IaaSVM.Azure.Windows"]$')
			$vm.AddProperty('$MPElement[Name="Windows!Microsoft.Windows.Computer"]/PrincipalName$', $PrincipalName)
			$vm.AddProperty('$MPElement[Name="System!System.Entity"]/DisplayName$', "Azure VM ($($metadata.compute.Name))")
			$vm.AddProperty('$MPElement[Name="CloudInstanceMetadata.Class.IaaSVM"]/Id$',$id)

			# Multiple Public and Private IPs possible based on schema

			$publicIPv4 = @()
			$privateIPv4 = @()

			foreach ($interface in $metadata.network.interface) {
				foreach ($ip in $interface.ipv4.ipAddress) {
					if (-not [string]::IsNullOrEmpty($ip.privateIpAddress)) {
						$privateIPv4 += $ip.privateIpAddress
					}

					if (-not [string]::IsNullOrEmpty($ip.publicIpAddress)) {
						$publicIPv4 += $ip.publicIpAddress
					}
				}
			}

			$vm.AddProperty('$MPElement[Name="CloudInstanceMetadata.Class.IaaSVM"]/PublicIPv4$', [string]::Join(", ", $publicIPv4))
			$vm.AddProperty('$MPElement[Name="CloudInstanceMetadata.Class.IaaSVM"]/PrivateIPv4$', [string]::Join(", ", $privateIPv4))
			$vm.AddProperty('$MPElement[Name="CloudInstanceMetadata.Class.IaaSVM.Azure"]/Name$', $metadata.compute.name)
			$vm.AddProperty('$MPElement[Name="CloudInstanceMetadata.Class.IaaSVM.Azure"]/Location$', $metadata.compute.location)
			$vm.AddProperty('$MPElement[Name="CloudInstanceMetadata.Class.IaaSVM.Azure"]/Offer$', $metadata.compute.offer)
			$vm.AddProperty('$MPElement[Name="CloudInstanceMetadata.Class.IaaSVM.Azure"]/OSType$', $metadata.compute.osType)
			$vm.AddProperty('$MPElement[Name="CloudInstanceMetadata.Class.IaaSVM.Azure"]/PlacementGroupId$', $metadata.compute.placementGroupId)
			$vm.AddProperty('$MPElement[Name="CloudInstanceMetadata.Class.IaaSVM.Azure"]/FaultDomain$', $metadata.compute.platformFaultDomain)
			$vm.AddProperty('$MPElement[Name="CloudInstanceMetadata.Class.IaaSVM.Azure"]/UpdateDomain$', $metadata.compute.platformUpdateDomain)
			$vm.AddProperty('$MPElement[Name="CloudInstanceMetadata.Class.IaaSVM.Azure"]/Publisher$', $metadata.compute.publisher)
			$vm.AddProperty('$MPElement[Name="CloudInstanceMetadata.Class.IaaSVM.Azure"]/ResourceGroup$', $metadata.compute.resourceGroupName)
			$vm.AddProperty('$MPElement[Name="CloudInstanceMetadata.Class.IaaSVM.Azure"]/SKU$', $metadata.compute.sku)
			$vm.AddProperty('$MPElement[Name="CloudInstanceMetadata.Class.IaaSVM.Azure"]/SubscriptionId$', $metadata.compute.subscriptionId)
			$vm.AddProperty('$MPElement[Name="CloudInstanceMetadata.Class.IaaSVM.Azure"]/Tags$', $metadata.compute.tags)
			$vm.AddProperty('$MPElement[Name="CloudInstanceMetadata.Class.IaaSVM.Azure"]/Version$', $metadata.compute.version)
			$vm.AddProperty('$MPElement[Name="CloudInstanceMetadata.Class.IaaSVM.Azure"]/Size$', $metadata.compute.vmSize)
			
			$discoveryData.AddInstance($vm)

		}
		
	} catch {}
}

# Return discovery data to SCOM
Write-output $discoveryData