# SCOM-CloudInstanceMetadata

A SCOM 2012+ management pack that discovers information from Cloud IaaS VMs using vendor instance metadata services.  Initially supports AWS EC2 and Microsoft Azure.

## Description

This MP uses the built-in Instance Metadata services available on both AWS and Azure to discover IaaS VM details from within the VM itself.  This requires no credentials, special connectivity or internet access.  A child object of Microsoft.Windows.Computer is created (this allows you to continue to use your extended Windows Computer class, if you have one).

There is currently no health rollup as this MP only discovers attributes, as the metadata services are not designed for monitoring data.  That said, with the properties discovered you could attach your own monitoring workflows to this class as you have all the key properties you need to do so via the vendors web APIs (you'd need to add credentials into SCOM).

## Management Packs

### CloudInstanceMetadata

This is the main pack in the solution, and has no special dependencies. It contains a handful of classes and groups, and performs the IaaS agent based discovery.  Requires some configuration (see the Requirements section below).

### AWSLinkDiscovery

This management pack uses a group populator discovery to create relationships between Amazon EC2 Instance objects discovered by the Amazon MP and the relevant Windows Computer, via the agent-based IaaS class.  This MP does not require any configuration, but has not been thoroughly performance tested in larger environments.  You should not import this unless you are monitoring instances using the Amazon MP.

### AzureLinkDiscovery

This management pack uses a group populator discovery to create relationships between Azure IaaS VM objects discovered by the Azure MP and the relevant Windows Computer, via the agent-based IaaS class.  This MP does not require any configuration, but has not been thoroughly performance tested in larger environments.  You should not import this unless you are monitoring instances using the Azure MP.

## Requirements

1. Import the MP into SCOM and put agents on your IaaS VMs.
1. Enable the Azure/AWS discoveries via override (they are disabled by default).  The PowerShell based discoveries will do the rest and require no-further configuration.
    * `Discover Azure Windows VM information`, targeting Windows Computer
    * `Discover AWS EC2 Windows VM information`, targeting Windows Computer
1. Create some views in SCOM and/or your 3rd Party dashboard product of choice.
1. (Optional) Import the AWS/AzureLinkDiscovery management pack.

## Troubleshooting

The PowerShell scripts by default run every 24 hours (or immediately after the agent is installed) and log to the `OperationsManager` event log using the following IDs:

* 6458 for Azure
* 6459 for AWS EC2

The discoveries use a series of "hints" (software installed, BIOS manufacturer) to decide if it is worth attempting to contact the instance metadata webservice. If you have some VMs where the discovery is not detecting that it should contact the service, you can override the discovery and enable the ForceAzure/ForceEC2 property, so they'll always try to contact it.

## Squared Up Dashboard pack

This pack is a sample that shows some of the dashboards and perspectives you can create using Squared Up v3.  It attempts to target generic classes, and whilst providing some visibility is not tailored to specific applications (providing visibility of Cloudwatch/Azure Insights alarms) and as such is probably too sparse for production use.

The use of _Status Icon/Block_ tiles to render instance information from related classes is a workaround to an issue that has already been corrected in the next feature release of Squared Up.  This will also make it possible to display child objects of the related class on a perspective (such as showing disks from the Cloud object, or Instance health from the agent object).

## TODO

* Linux VM support
* Google Cloud Platform VMs
