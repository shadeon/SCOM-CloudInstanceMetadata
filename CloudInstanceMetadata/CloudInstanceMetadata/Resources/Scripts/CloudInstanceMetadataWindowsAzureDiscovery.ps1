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

function Log-SCOMMessage {
	Param(
		[string]
		$message
	)

	$ScomAPI.LogScriptEvent("CloudInstanceMetadataWindowsAzureDiscovery.ps1", 6458, 0, $message)
}

Log-SCOMMessage -message "Script starting up"

# Test if Azure agent is running or BIOS and Manufacturer indicate MS VM
$azureAgentPresent = $null -ne (Get-Service -Name WindowsAzureGuestAgent -ErrorAction SilentlyContinue)
$computerProduct = (Get-WmiObject -Class Win32_ComputerSystemProduct)
$isMicrosoftVM = $computerProduct.Vendor -eq 'Microsoft Corporation' -and $computerProduct.Name -eq 'Virtual Machine'

if ($ForceAzure -or $azureAgentPresent -or $isMicrosoftVM) {

	Log-SCOMMessage -message "BIOS, running agents, or discovery override indicate we should try and contact the metadata service"
	# Attempt to contact Instance metadata
	
	Try {
		$response = Invoke-webrequest -Headers @{"Metadata"="true"} -URI 'http://169.254.169.254/metadata/instance?api-version=2019-08-15' -Method get -TimeoutSec 1 -UseBasicParsing -ErrorAction SilentlyContinue
		if ($response.statusCode -eq 200){
			Log-SCOMMessage -message "Processing instance metadata"
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
			$vm.AddProperty('$MPElement[Name="CloudInstanceMetadata.Class.IaaSVM.Azure"]/TagsList$',($metadata.compute.tagslist | ConvertTo-Json))
			$vm.AddProperty('$MPElement[Name="CloudInstanceMetadata.Class.IaaSVM.Azure"]/Version$', $metadata.compute.version)
			$vm.AddProperty('$MPElement[Name="CloudInstanceMetadata.Class.IaaSVM.Azure"]/Size$', $metadata.compute.vmSize)
			$vm.AddProperty('$MPElement[Name="CloudInstanceMetadata.Class.IaaSVM.Azure"]/vmScaleSetName$', $metadata.computevmScaleSetName)
			$vm.AddProperty('$MPElement[Name="CloudInstanceMetadata.Class.IaaSVM.Azure"]/Zone$', $metadata.compute.zone)
			$vm.AddProperty('$MPElement[Name="CloudInstanceMetadata.Class.IaaSVM.Azure"]/ResourceId$', $metadata.compute.ResourceId)
			$vm.AddProperty('$MPElement[Name="CloudInstanceMetadata.Class.IaaSVM.Azure"]/Provider$', $metadata.compute.Provider)
			$vm.AddProperty('$MPElement[Name="CloudInstanceMetadata.Class.IaaSVM.Azure"]/azEnvironment$', $metadata.compute.azEnvironment)
			$vm.AddProperty('$MPElement[Name="CloudInstanceMetadata.Class.IaaSVM.Azure"]/Plan$', ($metadata.compute.Plan | ConvertTo-Json))
			$vm.AddProperty('$MPElement[Name="CloudInstanceMetadata.Class.IaaSVM.Azure"]/StorageProfile$', ($metadata.compute.storageProfile | ConvertTo-Json))
			$vm.AddProperty('$MPElement[Name="CloudInstanceMetadata.Class.IaaSVM.Azure"]/vmId$', $metadata.compute.vmId)
			
			$discoveryData.AddInstance($vm)

		}
		else {
			Log-SCOMMessage -message "$($response.statusCode) Response returned attempting to contact instance metadata service."
		}
		
	} catch {
		if ($_.Exception -is [System.Net.WebException] -and $_.Exception.Status -eq [System.Net.WebExceptionStatus]::Timeout) {
			Log-SCOMMessage -message "Instance metadata service not available due to timeout - this is probably a Hyper-V VM."
		} else {
			Log-SCOMMessage -message "Instance metadata service not available.  Error message is:`n $($_.Exception)"
		}
	}
}

# Return discovery data to SCOM
$discoveryData
Log-SCOMMessage -message "Discovery complete."
