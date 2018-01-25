# SCOM-CloudInstanceMetadata

A SCOM 2012+ management pack that discovers information from Cloud IaaS VMs using vendor instance metadata services.  Initially supports AWS EC2 and Microsoft Azure.

## Description

This MP uses the built-in Instance Metadata services available on both AWS and Azure to discover IaaS VM details from within the VM itself.  This requires no credentials, special connectivity or internet access.  A child object of Microsoft.Windows.Computer is created (this allows you to continue to use your extended Windows Computer class, if you have one).

There is currently no health rollup as this MP only discovers attributes, as the metadata services are not designed for monitoring data.  That said, with the properties discovered you could attach your own monitoring workflows to this class as you have all the key properties you need to do so via the vendors web APIs (you'd need to add credentials into SCOM).

## Requirements

1. Import the MP into SCOM and put agents on your IaaS VMs.
1. Enable the Azure/AWS discoveries via override (they are disabled by default).  The PowerShell based discoveries will do the rest and require no-further configuration.
1. Create some views in SCOM and/or your 3rd Party dashboard product of choice.

## Troubleshooting

The PowerShell scripts by default run every 24 hours (or immediately after the agent is installed) and log to the `OperationsManager` event log using the following IDs:

* 6458 for Azure
* 6459 for AWS EC2

The discoveries use a series of "hints" (software installed, BIOS manufacturer) to decide if it is worth attempting to contact the instance metadata webservice. If you have some VMs where the discovery is not detecting that it should contact the service, you can override the discovery and enable the ForceAzure/ForceEC2 property, so they'll always try to contact it.

## TODO

* Linux VM support
* Google Cloud Platform VMs
* (Optional) Discoveries to relate objects discovered via the Official AWS/Azure Platform MPs with the hosting computer from these objects.
