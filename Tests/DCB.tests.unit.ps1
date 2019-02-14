﻿Describe "[Global Unit]" -Tag Global {
    BeforeAll {
        if (-not ((Get-Module -Name Pester -ListAvailable -ErrorAction SilentlyContinue)))
        {
            throw "[Global Unit]-[TestHost: ${env:ComputerName}] must have Pester module"
        }

        if ((Get-Module -Name Pester -ListAvailable -ErrorAction SilentlyContinue).Version.Major -ne 3)
        {
            throw "[Global Unit]-[TestHost: ${env:ComputerName}] must have Pester 3x module"
        }

        $NodeOS = Get-CimInstance -ClassName 'Win32_OperatingSystem'

        $caption = ($NodeOS.Caption -like '*Windows 10*') -or 
                    ($NodeOS.Caption -like '*Windows Server 2016*') -or
                    ($NodeOS.Caption -like '*Windows Server 2019*') 

        if (!$caption)
        {
            throw "[Global Unit]-[TestHost: ${env:ComputerName}] must be Windows 10, Server 2016, or Server 2019"
        }

        foreach ($module in @('DcbQos', 'NetQos', 'NetAdapter','ServerManager'))
        {
            if (-not (Get-Module $ -ListAvailable -ErrorAction SilentlyContinue))
            {
                throw "[Global Unit]-[TestHost: ${env:ComputerName}] must have the module [$module] available"
            }            
        }

        #Check cmdlets - This seems redundant since we already checked DcbQoS and NetQoS
        $cmdletsToCheck = 'Get-WindowsFeature', 'Get-NetQosPolicy', 'Get-NetQosFlowControl', `
        'Get-NetQosTrafficClass', 'Get-NetAdapterQos', 'Get-NetQosDcbxSetting'

        foreach ($cmd in $cmdletsToCheck)
        {
            if (-not (Get-Command $_ -ErrorAction SilentlyContinue))
            {
                throw "[Global Unit]-[TestHost: ${env:ComputerName}] must have the cmdlet [$cmd] available"
            }
        }

        ### Verify the config file exists
        $configFileExists = Get-ChildItem -Path $configFile -ErrorAction SilentlyContinue        
        if (-not $configFileExists)
        {
            throw "[Config File] $configFile must exist"
        }

        ### Verify configData contains the AllNodes HashTable
        if ($configData.AllNodes -isnot [System.Collections.Hashtable])
        {
            throw "[Config File]-[AllNodes] Config File must contain the AllNodes Hashtable"
        }

        ### Verify configData contains the NonNodeData HashTable
        if ($configData.NonNodeData -isnot [System.Collections.Hashtable])
        {
            throw "[Config File]-[NonNodeData] Config File must contain the NonNodeData Hashtable"
        }

        $legend = @('AllNodes','NonNodeData')
        $configData.Keys.GetEnumerator() | ForEach-Object {
            ### Verify that the entries under $configData are in $legend
            if ($_ -notin $legend)
            {
                throw "[Config File]-[Tested key: $_] Should contain only recognized keys"            
            }
        }

        ### Verify at least one node is specified [NodeName]
        if ($configData.AllNodes.NodeName.Count -le 0)
        {
            throw "[Config File]-[AllNodes.NodeName] Config File must contain at least 1 Node"
        }

        ### Verify nodes are only listed once in the config file [NodeName]
        $reference = $configData.AllNodes.NodeName | Select-Object -Unique -ErrorAction SilentlyContinue
        $difference = Compare-Object -ReferenceObject $reference -DifferenceObject $ConfigData.AllNodes.NodeName
        if ($null -ne $difference)
        {
            throw "[Config File]-[AllNodes.NodeName] Nodes cannot be specified more than once in the config file"
        }

        ### Verify Config File includes at least one RDMAEnabledAdapters entry
        if (($configData.AllNodes.RDMAEnabledAdapters + $configData.AllNodes.vmswitch.RDMAEnabledAdapters).Count -lt 1)
        {
            throw "[Config File]-[AllNodes] Must include at least one RDMAEnabledAdapters or vmswitch.RDMAEnabledAdapters entry"
        }

        foreach ($thisNode in $configData.AllNodes)
        {
            $AdapterEntry = 1

            $legend = @('NodeName','RDMAEnabledAdapters','RDMADisabledAdapters','VMSwitch')
            ($configData.AllNodes.Keys.GetEnumerator() | Select-Object -Unique) | ForEach-Object {
                ### Verify that the entries under $configData.AllNodes are in $legend
                if ($_ -notin $legend)
                {
                    throw "[Config File]-[AllNodes]-[$($thisNode.NodeName)]-[Tested key: $_] Should contain only recognized keys"                    
                }
            }

            foreach ($thisRDMADisabledAdapter in $thisNode.RDMADisabledAdapters)
            {
                $legend = @('Name')
                ($thisRDMADisabledAdapter.Keys.GetEnumerator() | Select-Object -Unique) | ForEach-Object {
                    ### Verify that the only entries under $configData.AllNodes.RDMADisabledAdapters are in $legend
                    if ($_ -notin $legend)
                    {                    
                        throw "[Config File]-[AllNodes.RDMADisabledAdapters]-[RDMADisabledAdapter: $($thisRDMADisabledAdapter.Name)]-[Tested key: $_]-Should contain only recognized keys"
                    }
                }
            }

            foreach ($thisRDMAEnabledAdapter in $thisNode.RDMAEnabledAdapters) {
                $legend = @('Name','VLANID','JumboPacket')
                ($thisRDMAEnabledAdapter.Keys.GetEnumerator() | Select-Object -Unique) | ForEach-Object {
                    ### Verify that the entries under $configData.AllNodes.RDMAEnabledAdapters are in $legend
                    if ($_ -notin $legend)
                    {
                        throw "[Config File]-[AllNodes.RDMAEnabledAdapters]-[RDMAEnabledAdapter: $($thisRDMAEnabledAdapter.Name)]-[Tested key: $_]-Should contain only recognized keys"                        
                    }
                }

                ### Verify each RDMAEnabledAdapter includes the Name property from Get-NetAdapter
                if ($null -eq $thisRDMAEnabledAdapter.Name)
                {
                    throw "[Config File]-[AllNodes.RDMAEnabledAdapters]-[Node: $($thisNode.NodeName)]-[Entry: $AdapterEntry]-[Noun: NetAdapter] Must include the Name property for each entry"
                }
    
                ### Verify each RDMAEnabledAdapter includes the VLANID property from Get-NetAdapterAdvancedProperty
                if ($null -eq $thisRDMAEnabledAdapter.VLANID)
                {
                    throw "[Config File]-[AllNodes.RDMAEnabledAdapters]-[Node: $($thisNode.NodeName)]-[Entry: $($thisRDMAEnabledAdapter.Name)]-[Noun: NetAdapterAdvancedProperty] Must include the VLANID property for each entry"
                }
    
                ### Verify each RDMAEnabledAdapter's VLANID property is not '0'
                if ($thisRDMAEnabledAdapter.VLANID -eq 0)
                {
                    throw "[Config File]-[AllNodes.RDMAEnabledAdapters]-[Node: $($thisNode.NodeName)]-[Entry: $($thisRDMAEnabledAdapter.Name)]-[Noun: NetAdapterAdvancedProperty] VLANID property should not be non-zero"
                }
                
                ### Verify RDMAEnabledAdapter Entry is not included in RDMADisabledAdapter
                if ($thisRDMAEnabledAdapter.Name -in $thisNode.RDMADisabledAdapters.Name)
                {
                    throw "[Config File]-[AllNodes.RDMAEnabledAdapters]-[Node: $($thisNode.NodeName)]-[Entry: $($thisRDMAEnabledAdapter.Name)]-[Noun: NetAdapterRDMA] Should not be in both RDMAEnabledAdapters and RDMADisabledAdapters"
                }

                ### Verify RDMAEnabledAdapter Entry is not included in vmswitch.RDMADisabledAdapter
                if ($thisRDMAEnabledAdapter.Name -in $thisNode.vmswitch.RDMADisabledAdapters.Name)
                {
                    throw "[Config File]-[AllNodes.RDMAEnabledAdapters]-[Node: $($thisNode.NodeName)]-[Entry: $($thisRDMAEnabledAdapter.Name)]-[Noun: NetAdapterRDMA] Should not be in both RDMAEnabledAdapters and vmswitch.RDMADisabledAdapters"
                }

                $AdapterEntry ++
            }

            $AdapterEntry = 1
            $VMSwitchEntry = 1

            foreach ($thisVMSwitch in $thisNode.vmSwitch) {
                $RDMADisabledAdapters = $thisVMSwitch.RDMADisabledAdapters
                $legend = @('Name','VMNetworkAdapter')

                foreach ($thisRDMADisabledAdapter in $RDMADisabledAdapters) {
                    $thisRDMADisabledAdapter.Keys.GetEnumerator() | ForEach-Object {
                        ### Verify entries under $configData.AllNodes.VMSwitch.RDMADisabledAdapters are in $legend
                        if ($_ -notin $legend)
                        {
                            throw "[Config File]-[AllNodes.VMSwitch.RDMADisabledAdapters]-[VMSwitch: $($thisVMSwitch.Name))]-[RDMADisabledAdapter: $($thisRDMADisabledAdapter.($_))]-[Tested key: $_]-Should contain only recognized keys"                        
                        }
                    }
                }
            }

            foreach ($thisVMSwitch in $thisNode.VMSwitch) {
                $legend = @('Name','EmbeddedTeamingEnabled','IovEnabled','LoadBalancingAlgorithm','RDMAEnabledAdapters','RDMADisabledAdapters')
                $thisVMSwitch.Keys.GetEnumerator() | ForEach-Object {
                    ### Verify that the entries under $configData.AllNodes.VMSwitch are in $legend
                    if ($_ -notin $legend)
                    {
                        throw "[Config File]-[AllNodes.VMSwitch.RDMAEnabledAdapters]-[Node: $($thisNode.NodeName)]-[Entry: $($thisVMSwitch.Name))]-[Tested key: $_]-Should contain only recognized keys"
                    }
                }

                ### Verify VMSwitch entry contains the Name property
                if ($null -eq $thisVMSwitch.Name)
                {
                    throw "[Config File]-[AllNodes.VMSwitch]-[Node: $($thisNode.NodeName)]-[Entry: $VMSwitchEntry)]-[Noun: VMSwitch] Must include the Name Property"
                }

                ### Verify VMSwitch entry contains the EmbeddedTeamingEnabled property
                if ($null -eq $thisVMSwitch.EmbeddedTeamingEnabled)
                {
                    throw "[Config File]-[AllNodes.VMSwitch]-[Node: $($thisNode.NodeName)]-[Entry: $($thisVMSwitch.Name))]-[Noun: VMSwitch] Must include the EmbeddedTeamingEnabled Property" 
                }

                ### Verify VMSwitch EmbeddedTeamingEnabled property is a boolean
                if ($thisVMSwitch.EmbeddedTeamingEnabled -isnot [System.Boolean])
                {
                    throw "[Config File]-[AllNodes.VMSwitch]-[Node: $($thisNode.NodeName)]-[Entry: $($thisVMSwitch.Name))]-[Noun: VMSwitch] EmbeddedTeamingEnabled Property must be a boolean"
                }

                If ($thisVMSwitch.ContainsKey('IovEnabled')) {
                    ### Verify VMSwitch IovEnabled property is a boolean
                    if ($thisVMSwitch.IovEnabled -isnot [System.Boolean])
                    {
                        throw "[Config File]-[AllNodes.VMSwitch]-[Node: $($thisNode.NodeName)]-[Entry: $($thisVMSwitch.Name))]-[Noun: VMSwitch] The IovEnabled property must be boolean"                    
                    }
                }

                If ($thisVMSwitch.ContainsKey('LoadBalancingAlgorithm')) {
                    ### Verify VMSwitch Load Balancing Algorithm is either Dynamic (2016 Default) or HyperVPort (2019 Default)
                    if (($thisVMSwitch.LoadBalancingAlgorithm -ne 'Dynamic') -or ($thisVMSwitch.LoadBalancingAlgorithm -ne 'HyperVPort'))
                    {
                        throw "[Config File]-[AllNodes.VMSwitch]-[Node: $($thisNode.NodeName)]-[Entry: $($thisVMSwitch.Name))]-[Noun: VMSwitch] The LoadBalancingAlgorithm property must be either HyperVPort or Dynamic "                        
                    }
                }

                $reference = $thisNode.VMSwitch.Name | Select-Object -Unique -ErrorAction SilentlyContinue

                ### Verify VMSwitch.Name entries are unique
                if ($null -ne (Compare-Object -ReferenceObject $reference -DifferenceObject $thisNode.VMSwitch.Name))
                {
                    throw "[Config File]-[AllNodes.VMSwitch] VMSwitch.Name cannot be specified more than once in the config file"
                }

                foreach ($thisRDMAEnabledAdapter in $thisVMSwitch.RDMAEnabledAdapters) {
                    $legend = @('Name','VMNetworkAdapter','VLANID','JumboPacket')
                    $thisRDMAEnabledAdapter.Keys.GetEnumerator() | ForEach-Object {
                        ### Verify that the only entries under $configData.AllNodes.VMSwitch.RDMAEnabledAdapters are in $legend
                        if ($_ -notin $legend)
                        {
                            throw "[Config File]-[AllNodes.VMSwitch.RDMAEnabledAdapters]-[Node: $($thisNode.NodeName)]-[Entry: $($thisVMSwitch.Name))]-[RDMAEnabledAdapter: $($thisRDMAEnabledAdapter.Name)]-[Tested Key: $_]-Should contain only recognized keys"
                        }
                    }

                    ### Verify each VMSwitch.RDMAEnabledAdapter includes the Name property from Get-NetAdapter
                    if ($null -eq $thisRDMAEnabledAdapter.Name)
                    {
                        throw "[Config File]-[AllNodes.VMSwitch.RDMAEnabledAdapters]-[Node: $($thisNode.NodeName)]-[Entry: $AdapterEntry]-[Noun: NetAdapter] Must include the Name property for each entry"
                    }

                    ### Verify each VMSwitch.RDMAEnabledAdapter includes the Name property from Get-VMNetworkAdapter -ManagementOS
                    if ($null -eq $thisRDMAEnabledAdapter.VMNetworkAdapter)
                    {
                        throw "[Config File]-[AllNodes.VMSwitch.RDMAEnabledAdapters]-[Node: $($thisNode.NodeName)]-[Entry: $($thisRDMAEnabledAdapter.Name)]-[Noun: VMNetworkAdapter] Must include the VMNetworkAdapter property for each entry"
                    }

                    ### Verify each VMSwitch.RDMAEnabledAdapter includes the VLANID property from Get-NetAdapterAdvancedProperty
                    if ($null -eq $thisRDMAEnabledAdapter.VLANID)
                    {
                        throw "[Config File]-[AllNodes.VMSwitch.RDMAEnabledAdapters]-[Node: $($thisNode.NodeName)]-[Entry: $($thisRDMAEnabledAdapter.Name)]-[Noun: NetAdapterAdvancedProperty] Must include the VLANID property for each entry"
                    }

                    ### Verify each VMSwitch.RDMAEnabledAdapter's VLANID property is not 0
                    if ($thisRDMAEnabledAdapter.VLANID -eq 0)
                    {
                        throw "[Config File]-[AllNodes.VMSwitch.RDMAEnabledAdapters]-[Node: $($thisNode.NodeName)]-[Entry: $($thisRDMAEnabledAdapter.Name)]-[Noun: NetAdapterAdvancedProperty] VLANID property should not be non-zero"
                    }

                    ### Verify each VMSwitch.RDMAEnabledAdapter entry is not included in RDMADisabledAdapter
                    if ($thisRDMAEnabledAdapter.Name -in $thisNode.RDMADisabledAdapters.Name)
                    {
                        throw "[Config File]-[AllNodes.VMSwitch.RDMAEnabledAdapters]-[Node: $($thisNode.NodeName)]-[Entry: $($thisRDMAEnabledAdapter.Name)]-[Noun: NetAdapterRDMA] Should not be in both VMSwitch.RDMAEnabledAdapters and RDMADisabledAdapters"
                    }

                    ### Verify VMSwitch.RDMAEnabledAdapter Entry is not included in VMSwitch.RDMADisabledAdapter
                    if ($thisRDMAEnabledAdapter.Name -in $thisNode.VMSwitch.RDMADisabledAdapters.Name)
                    {
                        throw "[Config File]-[AllNodes.VMSwitch.RDMAEnabledAdapters]-[Node: $($thisNode.NodeName)]-[Entry: $($thisRDMAEnabledAdapter.Name)]-[Noun: NetAdapterRDMA] Should not be in both VMSwitch.RDMAEnabledAdapters and VMSwitch.RDMADisabledAdapters"
                    }

                    $AdapterEntry ++
                }

                $VMSwitchEntry ++
            }
        }

        $legend = @('NetQos')
        $configData.NonNodeData.Keys.GetEnumerator() | ForEach-Object {
            ### Verify that the only entries under $configData.NonNodeData are in $legend
            if ($_ -notin $legend)
            {
                throw "[Config File]-[NonNodeData]-[Tested key: $_] Should contain only recognized keys"
            }
        }

        ### Verify NetQos is included in the config file
        if ($null -eq $ConfigData.NonNodeData.NetQos)
        {
            throw "[Config File]-[NonNodeData.NetQos] Config File must contain the NetQos section"
        }

        ### Verify at least 2 policies exist in the Qos Policies (Default and one for SMB)
        if ($ConfigData.NonNodeData.NetQos.Count -lt 1)
        {
            throw "[Config File]-[NonNodeData.NetQos]-[Noun: NetQosPolicy] NetQos must contain at least 2 policies"
        }

        ### Verify the default policy is specified in the config file
        if ($ConfigData.NonNodeData.NetQos.Name -notcontains 'Default')
        {
            throw "[Config File]-[NonNodeData.NetQos]-[Noun: NetQosPolicy] NetQos must specify a 'Default' policy"
        }

        # Note: Templates only specify TCP settings and do not apply to RDMA
        #       For RDMA, please use NetDirectPortMatchCondition 

        ### Verify At least one policy must specify the NetDirectPortMatchCondition
        if ($ConfigData.NonNodeData.NetQos.Keys -notcontains 'NetDirectPortMatchCondition')
        {
            throw "[Config File]-[NonNodeData.NetQos]-[Noun: NetQosPolicy] must specify the 'NetDirectPortMatchCondition' property for 1 policy"
        }

        ### Verify BandwidthPercentage totals 100
        if (($ConfigData.NonNodeData.NetQos.BandwidthPercentage | Measure-Object -Sum).Sum -ne 100)
        {
            throw "[Config File]-[NonNodeData.NetQos]-[Noun: NetQosTrafficClass] BandwidthPercentage must total 100%"
        }

        $policyEntry = 1

        foreach ($thisPolicy in $ConfigData.NonNodeData.NetQos)
        {
            $legend = @('Name', 'NetDirectPortMatchCondition', 'Template', 'PriorityValue8021Action', 'BandwidthPercentage', 'Algorithm')
            $thisPolicy.Keys.GetEnumerator() | ForEach-Object {
                ### Verify that the only entries under $configData.NonNodeData.NetQos are in $legend
                if ($_ -notin $legend)
                {
                    throw "[Config File]-[NonNodeData]-[Tested key: $_] Should contain only recognized keys"
                }
            }
            ### Verify Name property is specified for each policy
            if ($null -eq $thisPolicy.Name)
            {
                throw "[Config File]-[NonNodeData.NetQos]-[Policy Entry: $policyEntry]-[Noun: NetQosPolicy] Must specify the 'Name' property"            
            }

            ### Verify either NetDirectPortMatchCondition or Template are specified
            if (!($thisPolicy.NetDirectPortMatchCondition -or $thisPolicy.Template))
            {
                throw "[Config File]-[NonNodeData.NetQos]-[Policy: $($thisPolicy.Name)]-[Noun: NetQosPolicy] Must specify either 'Template' or 'NetDirectPortMatchCondition' property"
            }

            ### Verify PriorityValue8021Action is specified
            if ($null -eq $thisPolicy.PriorityValue8021Action)
            {
                throw "[Config File]-[NonNodeData.NetQos]-[Policy: $($thisPolicy.Name)]-[Noun: NetQosPolicy] Must specify the 'PriorityValue8021Action' property"
            }

            ### Verify BandwidthPercentage is specified
            if ($null -eq $thisPolicy.BandwidthPercentage)
            {
                throw "[Config File]-[NonNodeData.NetQos]-[Policy: $($thisPolicy.Name)]-[Noun: NetQosTrafficClass] Must specify the 'BandwidthPercentage' property"
            }

            ### Verify Algorithm is specified
            if ($null -eq $thisPolicy.Algorithm)
            {
                throw "[Config File]-[NonNodeData.NetQos]-[Policy: $($thisPolicy.Name)]-[Noun: NetQosTrafficClass] Must specify the 'Algorithm' property"
            }

            $policyEntry ++
        }
    }

    $ConfigData.AllNodes | ForEach-Object {
        $nodeName = $_.NodeName
        
        ### Verify Basic Network Connectivity to each Node
        if (-not (Test-NetConnection -ComputerName $nodeName -InformationLevel Quiet))
        {
            throw "[Global Unit]-[SUT: $nodeName] must respond to available over the network"
        }

        ### Verify each node responds to WinRM
        if (-not (Test-NetConnection -ComputerName $nodeName -CommonTCPPort WINRM -InformationLevel Quiet))
        {
            throw "[Global Unit]-[SUT: $nodeName] must respond to WinRM requests"
        }

        $NodeOS = Get-CimInstance -CimSession $nodeName -ClassName 'Win32_OperatingSystem'

        ### Verify the SUTs are Server SKU, 2016 or Higher
        $caption =  ($NodeOS.Caption -like '*Windows Server 2016*') -or
                    ($NodeOS.Caption -like '*Windows Server 2019*')

        if (!$caption)
        {
            throw "[Global Unit]-[SUT: $nodeName] must be Server 2016, or Server 2019"
        }

        $reqModules  = @('DcbQos', 'NetQos', 'NetAdapter','ServerManager')
        $reqFeatures = @('Data-Center-Bridging')

        if ($ConfigData.AllNodes.VMSwitch.Count -ge 1)
        {
            $reqFeatures += 'Hyper-V'
        }

        $actModules, $actFeatureState = Invoke-Command -ComputerName $nodeName -ScriptBlock {
            $modules      = Get-Module         -Name $using:reqModules -ListAvailable
            $featureState = Get-WindowsFeature -Name $using:reqFeatures
            return $Modules, $featureState
        }

        ### Verify that the required features exist on the SUT
        $reqFeatures | ForEach-Object {
            if (($actFeatureState | Where-Object Name -eq $_).InstallState -ne 'Installed')
            {
                throw "[Global Unit]-[SUT: $nodeName] should have the Windows Feature [$_] installed"
            } 
        }

        ### Verify that each required module existed on the SUT
        $reqModules | ForEach-Object {
            if (($actModules | Where-Object Name -eq $_) -ne $true)
            {
                throw "[Global Unit]-[SUT: $nodeName] should have the module [$_] installed"
            }
        }

        ### Verify the following cmdlets are available on each SUT
        'Get-WindowsFeature', 'Get-NetQosPolicy', 'Get-NetQosFlowControl', 
        'Get-NetQosTrafficClass', 'Get-NetAdapterQos', 'Get-NetQosDcbxSetting' | ForEach-Object {
            if ($actModules.ExportedCommands.Values -notcontains $_)
            {
                throw "[Global Unit]-[SUT: $nodeName] should have the cmdlet [$_] available"
            }
        }

        ### Verify none of the nodes are actually virtual machines
        if ((Get-CimInstance -ComputerName $nodeName -ClassName Win32_ComputerSystem) -eq 'Virtual Machine')
        {
            throw "[Global Unit]-[SUT: $nodeName] should not be a virtual machine"
        }
    }
}

Describe "[Modal Unit]" -Tag Modal {
    $configData.AllNodes | ForEach-Object {
        $thisNode = $_
        $nodeName = $thisNode.NodeName

        $cfgVMSwitch = $_.VMSwitch
        $cfgRDMAEnabledAdapters  = $_.RDMAEnabledAdapters
        $cfgRDMADisabledAdapters = $_.RDMADisabledAdapters

        $AllRDMAEnabledAdapters = @()
        If ($cfgRDMAEnabledAdapters) { $AllRDMAEnabledAdapters = $cfgRDMAEnabledAdapters}
        If ($cfgVMSwitch.RDMAEnabledAdapters) { $AllRDMAEnabledAdapters += $cfgVMSwitch.RDMAEnabledAdapters}

        $NetAdapter = @()
        $NetAdapter += Get-NetAdapter -CimSession $nodeName -Name $AllRDMAEnabledAdapters.Name -ErrorAction SilentlyContinue

        $NetAdapterBinding = @()
        $NetAdapterBinding += Get-NetAdapterBinding -CimSession $nodeName -Name $AllRDMAEnabledAdapters.Name -ErrorAction SilentlyContinue

        $actNetAdapterState = @{}
        $actNetAdapterState.NetAdapter        += $netAdapter
        $actNetAdapterState.netAdapterBinding += $netAdapterBinding

        Remove-Variable -Name NetAdapter, NetAdapterBinding

        foreach ($thisRDMAEnabledAdapter in $cfgRDMAEnabledAdapters) {
            Context "[Modal Unit]-[RDMAEnabledAdapters]-[SUT: $nodeName]-Physical NetAdapter Basic Checks" {
                ### Verify the interface is enabled
                It "[SUT: $nodeName]-[RDMAEnabledAdapter: $($thisRDMAEnabledAdapter.Name)]-[Noun: NetAdapter] Interface operation status must be `"Up`"" {
                    ($actNetAdapterState.NetAdapter | Where-Object Name -eq $thisRDMAEnabledAdapter.Name).Status | Should be 'Up'
                }

                ### Verify the interface has media link
                It "[SUT: $nodeName]-[RDMAEnabledAdapter: $($thisRDMAEnabledAdapter.Name)]-[Noun: NetAdapter] Interface media state must be `"Connected`"" {
                    ($actNetAdapterState.NetAdapter | Where-Object Name -eq $thisRDMAEnabledAdapter.Name).MediaConnectionState | Should Be 'Connected'
                }

                ### Verify interface is capable of 10+ Gbps
                It "[SUT: $nodeName]-[RDMAEnabledAdapter: $($thisRDMAEnabledAdapter.Name)]-[Noun: NetAdapter] Interface must be at least 10 Gbps" {
                    # Using 9000000000 (9 Gbps) since there is no -ge for Pester 3.x
                    ($actNetAdapterState.NetAdapter | Where-Object Name -eq $thisRDMAEnabledAdapter.Name).ReceiveLinkSpeed | Should BeGreaterThan 9000000000
                }

                ### Verify interface is physical hardware
                It "[SUT: $nodeName]-[RDMAEnabledAdapter: $($thisRDMAEnabledAdapter.Name)]-[Noun: NetAdapter] Interface must be physical hardware" {
                    ($actNetAdapterState.NetAdapter | Where-Object Name -eq $thisRDMAEnabledAdapter.Name).ConnectorPresent | Should Be $true
                }

                ### Verify interface IS NOT attached to virtual switch
                It "[SUT: $nodeName]-[RDMAEnabledAdapter: $($thisRDMAEnabledAdapter.Name)]-[Noun: NetAdapterBinding] Interface must not be attached to the virtual switch" {
                    $testedBinding = ($actNetAdapterState.NetAdapterBinding | Where-Object{ $_.Name -eq $thisRDMAEnabledAdapter.Name -and $_.ComponentID -eq 'vms_pp'}).Enabled
                    $testedBinding -eq $Null -or $testedBinding -eq $false | Should be $true
                }

                ### Verify interface is NOT bound to LBFO
                It "[SUT: $nodeName]-[RDMAEnabledAdapter: $($thisRDMAEnabledAdapter.Name)]-[Noun: NetAdapterBinding] Interface should NOT be bound to the LBFO multiplexor" {
                    ($actNetAdapterState.netAdapterBinding | Where-Object{$_.Name -eq $thisRDMAEnabledAdapter.Name -and $_.ComponentID -eq 'ms_implat'}).Enabled | Should be $false
                }

                #Note: $thisDriver will be empty if using a driver that is not recognized
                $driverName = ($actNetAdapterState.NetAdapter | Where-Object Name -eq $thisRDMAEnabledAdapter.Name).DriverName.Split('\')
                $thisDriver = $drivers.Where{$_.DriverFileName -eq $driverName[$driverName.Count - 1]}

                ### Verify interface is using a known adapter
                    #TODO: Update once certifications are complete
                It "[SUT: $nodeName]-[RDMAEnabledAdapter: $($thisRDMAEnabledAdapter.Name)]-[Noun: NetAdapter] Must use a certified device [e.g. Cavium, Chelsio, Intel, Broadcom, Mellanox]" {
                    $thisDriver | Should not BeNullOrEmpty
                }

                ### Verify interface is using at least the recommended driver version
                It "[SUT: $nodeName]-[RDMAEnabledAdapter: $($thisRDMAEnabledAdapter.Name)]-[Noun: NetAdapter] Driver must use the recommended version ($($thisDriver.MinimumDriverVersion) or later" {
                    ($actNetAdapterState.NetAdapter | Where-Object Name -eq $thisRDMAEnabledAdapter.Name).DriverVersionString -ge $thisDriver.MinimumDriverVersion | Should be $true
                }
            }
        }

        foreach ($thisCfgVMSwitch in $cfgVMSwitch) {
            foreach ($thisRDMAEnabledAdapter in $thisCfgVMSwitch.RDMAEnabledAdapters) {
                Context "[Modal Unit]-[VMSwitch.RDMAEnabledAdapters]-[SUT: $nodeName]-Physical NetAdapter Basic Checks" {
                    ### Verify the interface is enabled
                    It "[SUT: $nodeName]-[VMSwitch: $($thisCfgVMSwitch.Name)]-[RDMAEnabledAdapter: $($thisRDMAEnabledAdapter.Name)]-[Noun: NetAdapter] Interface operation status must be `"Up`"" {
                        ($actNetAdapterState.NetAdapter | Where-Object Name -eq $thisRDMAEnabledAdapter.Name).Status | Should Be 'Up'
                    }

                    ### Verify the interface has media link
                    It "[SUT: $nodeName]-[VMSwitch: $($thisCfgVMSwitch.Name)]-[RDMAEnabledAdapter: $($thisRDMAEnabledAdapter.Name)]-[Noun: NetAdapter] Interface media state must be `"Connected`"" {
                        ($actNetAdapterState.NetAdapter | Where-Object Name -eq $thisRDMAEnabledAdapter.Name).MediaConnectionState | Should Be 'Connected'
                    }

                    ### Verify interface is capable of 10+ Gbps
                    It "[SUT: $nodeName]-[VMSwitch: $($thisCfgVMSwitch.Name)]-[RDMAEnabledAdapter: $($thisRDMAEnabledAdapter.Name)]-[Noun: NetAdapter] Interface must be at least 10 Gbps" {
                        # Using 9000000000 (9 Gbps) since there is no -ge for Pester 3.x
                        ($actNetAdapterState.NetAdapter | Where-Object Name -eq $thisRDMAEnabledAdapter.Name).ReceiveLinkSpeed | Should BeGreaterThan 9000000000
                    }

                    ### Verify interface is physical hardware
                    It "[SUT: $nodeName]-[VMSwitch: $($thisCfgVMSwitch.Name)]-[RDMAEnabledAdapter: $($thisRDMAEnabledAdapter.Name)]-[Noun: NetAdapter] Interface must be physical hardware" {
                        ($actNetAdapterState.NetAdapter | Where-Object Name -eq $thisRDMAEnabledAdapter.Name).ConnectorPresent | Should Be $true
                    }

                    ### Verify interface IS attached to virtual switch
                    It "[SUT: $nodeName]-[VMSwitch: $($thisCfgVMSwitch.Name)]-[RDMAEnabledAdapter: $($thisRDMAEnabledAdapter.Name)]-[Noun: NetAdapterBinding] Interface MUST be attached to the virtual switch" {
                        ($actNetAdapterState.NetAdapterBinding | Where-Object{ $_.Name -eq $thisRDMAEnabledAdapter.Name -and $_.ComponentID -eq 'vms_pp'}).Enabled | Should Be $true
                    }

                    ### Verify interface is NOT bound to LBFO
                    It "[SUT: $nodeName]-[VMSwitch: $($thisCfgVMSwitch.Name)]-[RDMAEnabledAdapter: $($thisRDMAEnabledAdapter.Name)]-[Noun: NetAdapterBinding] Interface must NOT be bound to the LBFO multiplexor" {
                        ($actNetAdapterState.netAdapterBinding | Where-Object{$_.Name -eq $thisRDMAEnabledAdapter.Name -and $_.ComponentID -eq 'ms_implat'}).Enabled | Should be $false
                    }

                    #Note: $thisDriver will be empty if using a driver that is not recognized
                    $driverName = ($actNetAdapterState.NetAdapter | Where-Object Name -eq $thisRDMAEnabledAdapter.Name).DriverName.Split('\')
                    $thisDriver = $drivers.Where{$_.DriverFileName -eq $driverName[$driverName.Count - 1]}

                    ### Verify interface is using a known adapter
                        #TODO: Update once certifications are complete
                    It "[SUT: $nodeName]-[VMSwitch: $($thisCfgVMSwitch.Name)]-[RDMAEnabledAdapter: $($thisRDMAEnabledAdapter.Name)]-[Noun: NetAdapter] Must use a known device [e.g. Cavium, Chelsio, Intel, Broadcom, Mellanox]" {
                        $thisDriver | Should not BeNullOrEmpty
                    }

                    ### Verify interface is using at least the recommended driver version
                    It "[SUT: $nodeName]-[VMSwitch: $($thisCfgVMSwitch.Name)]-[RDMAEnabledAdapter: $($thisRDMAEnabledAdapter.Name)]-[Noun: NetAdapter] Driver must use the recommended version ($($thisDriver.MinimumDriverVersion)) or later" {
                        ($actNetAdapterState.NetAdapter | Where-Object Name -eq $thisRDMAEnabledAdapter.Name).DriverVersionString -ge $thisDriver.MinimumDriverVersion | Should be $true
                    }
                }
            }
        }

        $netAdapterAdvancedProperty = @()
        $netAdapterAdvancedProperty += Get-NetAdapterAdvancedProperty -CimSession $nodeName -Name $AllRDMAEnabledAdapters.Name -ErrorAction SilentlyContinue
        
        $actNetAdapterState.netAdapterAdvancedProperty = $netAdapterAdvancedProperty
    
        Remove-Variable -Name netAdapterAdvancedProperty

        foreach ($thisRDMAEnabledAdapter in $cfgRDMAEnabledAdapters) {
            Context "[Modal Unit]-[RDMAEnabledAdapters]-[SUT: $nodeName]-Physical NetAdapter Advanced Property Settings" {
                ### Verify Interface is RDMA Capable (includes the *NetworkDirect Keyword)
                It "[SUT: $nodeName]-[RDMAEnabledAdapter: $($thisRDMAEnabledAdapter.Name)]-[Noun: NetAdapterAdvancedProperty] should be NetworkDirect (RDMA) capable" {
                    $actNetAdapterState.netAdapterAdvancedProperty | Where-Object{$_.Name -eq $thisRDMAEnabledAdapter.Name -and $_.RegistryKeyword -eq '*NetworkDirect'} | Should Not BeNullOrEmpty
                }
                
                ### Verify Interface is RDMA Enabled
                It "[SUT: $nodeName]-[RDMAEnabledAdapter: $($thisRDMAEnabledAdapter.Name)]-[Noun: NetAdapterAdvancedProperty] should have NetworkDirect (RDMA) Enabled" {
                    ($actNetAdapterState.netAdapterAdvancedProperty | Where-Object{$_.Name -eq $thisRDMAEnabledAdapter.Name -and $_.RegistryKeyword -eq '*NetworkDirect'}).DisplayValue | Should Be 'Enabled'
                }
            
                ### Verify Interface has a VLAN assigned - These NICs are native adapters (no VMSwitch attached)
                It "[SUT: $nodeName]-[RDMAEnabledAdapter: $($thisRDMAEnabledAdapter.Name)]-[Noun: NetAdapterAdvancedProperty] should have VLAN $($thisRDMAEnabledAdapter.VLANID) assigned" {
                    ($actNetAdapterState.netAdapterAdvancedProperty | Where-Object{$_.Name -eq $thisRDMAEnabledAdapter.Name -and $_.RegistryKeyword -eq 'VLANID'}).RegistryValue | Should Be $thisRDMAEnabledAdapter.VLANID
                }
            
                ### Verify if JumboPackets are specified in the config file that they are set properly on the interfaces
                If ($thisRDMAEnabledAdapter.JumboPacket) {
                    It "[SUT: $nodeName]-[RDMAEnabledAdapter: $($thisRDMAEnabledAdapter.Name)]-[Noun: NetAdapterAdvancedProperty] should have Jumbo Frames set to [$($thisRDMAEnabledAdapter.JumboPacket)]" {
                        ($actNetAdapterState.netAdapterAdvancedProperty | Where-Object{$_.Name -eq $thisRDMAEnabledAdapter.Name -and $_.RegistryKeyword -eq '*JumboPacket'}).RegistryValue | Should Be $thisRDMAEnabledAdapter.JumboPacket
                    }
                }

                #Note: $thisDriver will be empty if using a driver that is not recognized
                $driverName = ($actNetAdapterState.NetAdapter | Where-Object Name -eq $thisRDMAEnabledAdapter.Name).DriverName.Split('\')
                $thisIHV = $drivers.Where{$_.DriverFileName -eq $driverName[$driverName.Count - 1]}.IHV

                Switch ($thisIHV) {
                    'Chelsio ' { }
                    'Cavium'   { }
                    'Intel'    { }

                    'Mellanox' { 
                        It "[SUT: $nodeName]-[Adapter: $($thisRDMAEnabledAdapter.Name)]-(Noun: NetAdapterAdvancedProperty) Miniport IPv4 RSC should be disabled" {
                            (($actNetAdapterState.netAdapterAdvancedProperty | Where-Object Name -eq $thisRDMAEnabledAdapter.Name) | Where-Object RegistryKeyword -eq '*RscIPv4').RegistryValue | Should Be 0
                        }

                        It "[SUT: $nodeName]-[Adapter: $($thisRDMAEnabledAdapter.Name)]-(Noun: NetAdapterAdvancedProperty) Miniport IPv6 RSC should be disabled" {
                            (($actNetAdapterState.netAdapterAdvancedProperty | Where-Object Name -eq $thisRDMAEnabledAdapter.Name) | Where-Object RegistryKeyword -eq '*RscIPv6').RegistryValue | Should Be 0
                        }
                    }

                    'Broadcom' { }

                    'Default'  {
                        It 'Hardware Vendor for Adapter not Identified' { $false | Should be $true }
                    }
                }
            }
        }

        foreach ($thisCfgVMSwitch in $cfgVMSwitch) {
            foreach ($thisRDMAEnabledAdapter in $cfgVMSwitch.RDMAEnabledAdapters) {
                Context "[Modal Unit]-[VMSwitch.RDMAEnabledAdapters]-[SUT: $nodeName]-Physical NetAdapter Advanced Property Settings" {
                    ### Verify Interface is RDMA Capable (includes the *NetworkDirect Keyword)
                    It "[SUT: $nodeName]-[VMSwitch: $($thisCfgVMSwitch.Name)]-[RDMAEnabledAdapter: $($thisRDMAEnabledAdapter.Name)]-[Noun: NetAdapterAdvancedProperty] should be NetworkDirect (RDMA) capable" {
                        $actNetAdapterState.netAdapterAdvancedProperty | Where-Object{$_.Name -eq $thisRDMAEnabledAdapter.Name -and $_.RegistryKeyword -eq '*NetworkDirect'} | Should Not BeNullOrEmpty
                    }
                    
                    ### Verify Interface is RDMA Enabled
                    It "[SUT: $nodeName]-[VMSwitch: $($thisCfgVMSwitch.Name)]-[RDMAEnabledAdapter: $($thisRDMAEnabledAdapter.Name)]-[Noun: NetAdapterAdvancedProperty] should have NetworkDirect (RDMA) Enabled" {
                        ($actNetAdapterState.netAdapterAdvancedProperty | Where-Object{$_.Name -eq $thisRDMAEnabledAdapter.Name -and $_.RegistryKeyword -eq '*NetworkDirect'}).DisplayValue | Should Be 'Enabled'
                    }
                
                    ### Verify Interface has a VLAN of 0 - These NICs are attached to a VMSwitch attached, so vNICs will have the VLANID
                    It "[SUT: $nodeName]-[VMSwitch: $($thisCfgVMSwitch.Name)]-[RDMAEnabledAdapter: $($thisRDMAEnabledAdapter.Name)]-[Noun: NetAdapterAdvancedProperty] should have VLAN '0' assigned" {
                        ($actNetAdapterState.netAdapterAdvancedProperty | Where-Object{$_.Name -eq $thisRDMAEnabledAdapter.Name -and $_.RegistryKeyword -eq 'VLANID'}).RegistryValue | Should Be 0
                    }
                
                    ### Verify if JumboPackets are specified in the config file that they are set properly on the interfaces
                    If ($thisRDMAEnabledAdapter.JumboPacket) {
                        It "[SUT: $nodeName]-[VMSwitch: $($thisCfgVMSwitch.Name)]-[RDMAEnabledAdapter: $($thisRDMAEnabledAdapter.Name)]-[Noun: NetAdapterAdvancedProperty] should have Jumbo Frames set to [$($thisRDMAEnabledAdapter.JumboPacket)]" {
                            ($actNetAdapterState.netAdapterAdvancedProperty | Where-Object{$_.Name -eq $thisRDMAEnabledAdapter.Name -and $_.RegistryKeyword -eq '*JumboPacket'}).RegistryValue | Should Be $thisRDMAEnabledAdapter.JumboPacket
                        }
                    }
                }
            }
        }
        
        # No Disabled Adapters need to be specified, so only run this if there are disabled adapters
        if ($cfgRDMADisabledAdapters.Name -or $cfgVMSwitch.RDMADisabledAdapters.Name) {
            $DisabledNetAdapterAdvancedProperty = @()
            $DisabledNetAdapterAdvancedProperty += Get-NetAdapterAdvancedProperty -CimSession $nodeName -Name $cfgRDMADisabledAdapters.Name, $cfgVMSwitch.RDMADisabledAdapters.Name -ErrorAction SilentlyContinue
            
            $actNetAdapterState.DisabledNetAdapterAdvancedProperty = $DisabledNetAdapterAdvancedProperty

            #TODO: Make sure this works with multiple vmswitch.adapters
            Context "[Modal Unit]-[DisabledAdapters]-[SUT: $nodeName]-RDMA Disabled Physical NetAdapter" {
                foreach ($thisRDMADisabledAdapter in $cfgRDMADisabledAdapters.Name) {
                    ### Verify RDMA is disabled or not capable on this adapter
                    It "[SUT: $nodeName]-[RDMADisabledAdapter: $($thisRDMAEnabledAdapter.Name)]-[Noun: NetAdapterAdvancedProperty] should have NetworkDirect (RDMA) Disabled" {
                        ($actNetAdapterState.DisabledNetAdapterAdvancedProperty | Where-Object{$_.Name -eq $thisRDMADisabledAdapter.Name -and $_.RegistryKeyword -eq '*NetworkDirect'}).DisplayValue | Should Not Be 'Enabled'
                    }
                }
    
                foreach ($thisRDMADisabledAdapter in $cfgVMSwitch.RDMADisabledAdapters.Name) {
                    ### Verify RDMA is disabled or not capable on this adapter
                    It "[SUT: $nodeName]-[VMSwitch.RDMADisabledAdapter: $($thisRDMAEnabledAdapter)]-[Noun: NetAdapterAdvancedProperty] should have NetworkDirect (RDMA) Disabled" {
                        ($actNetAdapterState.DisabledNetAdapterAdvancedProperty | Where-Object{$_.Name -eq $thisRDMADisabledAdapter -and $_.RegistryKeyword -eq '*NetworkDirect'}).DisplayValue | Should Not Be 'Enabled'
                    }
                }

                foreach ($thisRDMADisabledAdapter in $cfgVMSwitch.RDMADisabledAdapters.VMNetworkAdapter) {
                    ### Verify RDMA is disabled on this VMNetworkAdapter adapter
                    It "[SUT: $nodeName]-[VMSwitch.RDMADisabledAdapter: $($thisRDMAEnabledAdapter)]-[Noun: NetAdapterAdvancedProperty] should have NetworkDirect (RDMA) Disabled" {
                        ($actNetAdapterState.DisabledNetAdapterAdvancedProperty | Where-Object{$_.Name -eq $thisRDMADisabledAdapter -and $_.RegistryKeyword -eq '*NetworkDirect'}).DisplayValue | Should Not Be 'Enabled'
                    }
                }
            }
        }
    
        Context "[Modal Unit]-[NetQos]-[SUT: $nodeName]-NetQos Settings" {
            $NetQosPolicy       = Get-NetQosPolicy       -CimSession $nodeName -ErrorAction SilentlyContinue
            $NetAdapterQos      = Get-NetAdapterQos      -CimSession $nodeName -ErrorAction SilentlyContinue
            $NetQosFlowControl  = Get-NetQosFlowControl  -CimSession $nodeName -ErrorAction SilentlyContinue
            $NetQosTrafficClass = Get-NetQosTrafficClass -CimSession $nodeName -ErrorAction SilentlyContinue
    
            $NetQosDcbxSettingInterfaces = @()
            $AllRDMAEnabledAdapters.Name | ForEach-Object {
                $NetQosDcbxSettingInterfaces  += Get-NetQosDcbxSetting -InterfaceAlias $_ -CimSession $nodeName -ErrorAction SilentlyContinue
            }
            
            $actNetQoSState = @{}
            $actNetQoSState.NetQoSPolicy       = $NetQosPolicy
            $actNetQoSState.NetAdapterQos      = $NetAdapterQos
            $actNetQoSState.NetQoSFlowControl  = $NetQosFlowControl
            $actNetQoSState.NetQosTrafficClass = $NetQosTrafficClass
            $actNetQoSState.NetQosDcbxSettingInterfaces = $NetQosDcbxSettingInterfaces
    
            Remove-Variable -Name NetQosPolicy, NetAdapterQos, NetQosFlowControl, NetQosTrafficClass, NetQosDcbxSettingInterfaces
    
            foreach ($thisPolicy in $configData.NonNodeData.NetQoS) {
                ### Verify this NetQos Policy exists
                It "[SUT: $nodeName]-[NetQos: $($thisPolicy.Name)]-[Noun: NetQosPolicy] should have a NetQos policy named ($($thisPolicy.Name)) assigned" {
                    $actNetQoSState.NetQoSPolicy.Name -contains $($thisPolicy.Name) | Should Be $true
                }

                If ($thisPolicy.Template) {
                    ### Verify this NetQos policy uses the specified template
                    It "[SUT: $nodeName]-[NetQos: $($thisPolicy.Name)]-[Noun: NetQosPolicy] The NetQos policy named ($($thisPolicy.Name)) should be the ($($thisPolicy.Name)) template" {
                        ($actNetQoSState.NetQoSPolicy | Where-Object Name -eq $thisPolicy.Name).Template | Should Be $thisPolicy.Template
                    }
                }
                elseif ($thisPolicy.NetDirectPortMatchCondition) {
                    ### Verify this NetQos policy uses the specified NetDirectPortMatchCondition
                    It "[SUT: $nodeName]-[NetQos: $($thisPolicy.Name)]-[Noun: NetQosPolicy] The NetQos policy named ($($thisPolicy.Name)) should be assigned port ($($thisPolicy.NetDirectPortMatchCondition))" {
                        ($actNetQoSState.NetQoSPolicy | Where-Object Name -eq $thisPolicy.Name).NetDirectPortMatchCondition | Should Be $thisPolicy.NetDirectPortMatchCondition
                    }
                }

                ### Verify this NetQos policy is the specified priority
                It "[SUT: $nodeName]-[NetQos: $($thisPolicy.Name)]-[Noun: NetQosPolicy] The NetQos policy named ($($thisPolicy.Name)) should be priority ($($thisPolicy.PriorityValue8021Action))" {
                    ($actNetQoSState.NetQoSPolicy | Where-Object Name -eq $thisPolicy.Name).PriorityValue8021Action | Should Be $thisPolicy.PriorityValue8021Action
                }

                If ( -not( $($thisPolicy.Name) -like '*default*' )) {
                    ### Verify the NetQos Priority is Enabled
                    It "[SUT: $nodeName]-[NetQos: $($thisPolicy.Name)]-[Noun: NetQoSFlowControl] The NetQoS priority ($($thisPolicy.PriorityValue8021Action)) for policy ($($thisPolicy.Name)) should be enabled" {
                        ($actNetQoSState.NetQoSFlowControl | Where-Object Priority -eq $thisPolicy.PriorityValue8021Action).Enabled | Should Be $true
                    }
                }

                If (( $($thisPolicy.Name) -like '*default*' )) {
                    ### Verify Should have the specified traffic class
                    It "[SUT: $nodeName]-[NetQos: $($thisPolicy.Name)]-[Noun: NetQosTrafficClass] Should have a traffic class named '[$($thisPolicy.Name)]'" {
                        $actNetQoSState.NetQosTrafficClass.Name -contains "[$($thisPolicy.Name)]" | Should Be $true
                    }
    
                    ### Verify this traffic class is the expected BandwidthPercentage
                    It "[SUT: $nodeName]-[NetQos: $($thisPolicy.Name)]-[Noun: NetQosTrafficClass] The traffic class named '[$($thisPolicy.Name)]' should have a bandwidth percentage of ($($thisPolicy.BandwidthPercentage))" {
                        ($actNetQoSState.NetQosTrafficClass | Where-Object Name -Like '*default*').BandwidthPercentage | Should Be $thisPolicy.BandwidthPercentage
                    }
    
                    ### Verify this traffic class is the expected Algorithm
                    It "[SUT: $nodeName]-[NetQos: $($thisPolicy.Name)]-[Noun: NetQosTrafficClass] The traffic class named '[$($thisPolicy.Name)]' should have an algorithm of ($($thisPolicy.Algorithm))" {
                        ($actNetQoSState.NetQosTrafficClass | Where-Object Name -Like '*default*').Algorithm | Should Be $thisPolicy.Algorithm
                    }
                }
                Else {
                    ### Verify Should have the specified traffic class
                    It "[SUT: $nodeName]-[NetQos: $($thisPolicy.Name)]-[Noun: NetQosTrafficClass] Should have a traffic class named ($($thisPolicy.Name))" {
                        $actNetQoSState.NetQosTrafficClass.Name -contains "$($thisPolicy.Name)" | Should Be $true
                    }
    
                    ### Verify This traffic class is the expected priority  
                    It "[SUT: $nodeName]-[NetQos: $($thisPolicy.Name)]-[Noun: NetQosTrafficClass] The traffic class named ($($thisPolicy.Name)) should be priority ($($thisPolicy.PriorityValue8021Action))" {
                        ($actNetQoSState.NetQosTrafficClass | Where-Object Name -eq "$($thisPolicy.Name)").Priority | Should Be $thisPolicy.PriorityValue8021Action
                    }
    
                    ### Verify this traffic class is the expected BandwidthPercentage
                    It "[SUT: $nodeName]-[NetQos: $($thisPolicy.Name)]-[Noun: NetQosTrafficClass] The traffic class named ($($thisPolicy.Name)) should have a bandwidth percentage of ($($thisPolicy.BandwidthPercentage))" {
                        ($actNetQoSState.NetQosTrafficClass | Where-Object Name -eq $thisPolicy.Name).BandwidthPercentage | Should Be $thisPolicy.BandwidthPercentage
                    }
    
                    ### Verify this traffic class is the expected Algorithm
                    It "[SUT: $nodeName]-[NetQos: $($thisPolicy.Name)]-[Noun: NetQosTrafficClass] The traffic class named ($($thisPolicy.Name)) should have a algorithm of ($($thisPolicy.Algorithm))" {
                        ($actNetQoSState.NetQosTrafficClass | Where-Object Name -eq $thisPolicy.Name).Algorithm | Should Be $thisPolicy.Algorithm
                    }
                }
            }

            foreach ($thisRDMAEnabledAdapter in $AllRDMAEnabledAdapters) {
                ### Verify this adapter has an enabled NetAdapterQos policy
                It "[SUT: $nodeName]-[RDMAEnabledAdapters: $($thisRDMAEnabledAdapter.Name)]-[Noun: NetAdapterQos] should be enabled" {
                    ($actNetQoSState.NetAdapterQos | Where-Object Name -eq $thisRDMAEnabledAdapter.Name).Enabled | Should Be $true
                }
    
                ### Verify this adapter's DCBX setting is not Willing
                It "[SUT: $nodeName]-[RDMAEnabledAdapters: $($thisRDMAEnabledAdapter.Name)]-[Noun: NetQosDcbxSetting] interfaces DCBX 'Willing' option should be false" {
                    ($actNetQoSState.NetQosDcbxSettingInterfaces | Where-Object InterfaceAlias -like $thisRDMAEnabledAdapter.Name).Willing | Should Be 'false'
                }
            }
        }

        foreach ($thisCfgVMSwitch in $cfgVMSwitch) {
            $vmSwitch     = Get-VMSwitch     -Name $thisCfgVMSwitch.Name -CimSession $nodeName -ErrorAction SilentlyContinue
            $vmSwitchTeam = Get-VMSwitchTeam -Name $thisCfgVMSwitch.Name -CimSession $nodeName -ErrorAction SilentlyContinue

            $actvmSwitch = @{}
            $actvmSwitch.vmSwitch     = $vmSwitch
            $actvmSwitch.vmSwitchTeam = $vmSwitchTeam
            
            If ($thisCfgVMSwitch.IovEnabled) {
                $NetAdapterSRIOV = @()

                foreach ($thisRDMAEnabledAdapter in $thisCfgVMSwitch.RDMAEnabledAdapters) {
                    $NetAdapterSRIOV += Get-NetAdapterSRIOV -Name $thisRDMAEnabledAdapter.Name -CimSession $nodeName -ErrorAction SilentlyContinue
                }

                $actvmSwitch.NetAdapterSRIOV = $NetAdapterSRIOV
            }

            Remove-Variable -Name VMSwitch, VMSwitchTeam, NetAdapterSRIOV -ErrorAction SilentlyContinue

            Context "[Modal Unit]-[VMSwitch: $($thisCfgVMSwitch.Name)]-[SUT: $nodeName]-VMSwitch Settings" {
                ### Verify the expected VMSwitch exists
                It "[SUT: $nodeName]-[VMSwitch: $($thisCfgVMSwitch.Name)]-[Noun: VMSwitch] vSwitch should exist" {
                    ($actvmSwitch.vmSwitch | Where-Object Name -eq $thisCfgVMSwitch.Name).Name | Should Be $thisCfgVMSwitch.Name
                }

                Switch ($thisCfgVMSwitch.EmbeddedTeamingEnabled) {
                    $false {
                        ### Verify Non-teamed interfaces contain only 1 adapter specified
                        It "[SUT: $nodeName]-[VMSwitch: $($thisCfgVMSwitch.Name)]-[Noun: VMSwitch] vSwitch should contain only 1 adapter" {
                            ($actvmSwitch.vmSwitch | Where-Object Name -eq $thisCfgVMSwitch.Name).NetAdapterInterfaceDescriptions.Count | Should Be 1
                        }

                        ### Verify LBFO Multiplexor is not used
                        It "[SUT: $nodeName]-[VMSwitch: $($thisCfgVMSwitch.Name)]-[Noun: VMSwitch] vSwitch should not use LBFO Teaming" {
                            ($actvmSwitch.vmSwitch | Where-Object Name -eq $thisCfgVMSwitch.Name).NetAdapterInterfaceDescription | Should Not Be 'Microsoft Network Adapter Multiplexor Driver'
                        }

                        ### Verify Non-teamed interfaces are actually non-teamed
                        It "[SUT: $nodeName]-[VMSwitch: $($thisCfgVMSwitch.Name)]-[Noun: VMSwitch] vSwitch should not be a teamed interface" {
                            ($actvmSwitch.vmSwitch | Where-Object Name -eq $thisCfgVMSwitch.Name).NetAdapterInterfaceDescription | Should Not Be 'Teamed-Interface'
                        }

                        ### Verify the expected adapter is attached to the vSwitch
                        It "[SUT: $nodeName]-[VMSwitch: $($thisCfgVMSwitch.Name)]-[Noun: VMSwitch] vSwitch interface should be [$($thisCfgVMSwitch.RDMAEnabledAdapters.Name)]" {
                            $thisInterfaceDescription = ($actvmSwitch.vmSwitch | Where-Object Name -eq $thisCfgVMSwitch.Name).NetAdapterInterfaceDescription
                            ($actNetAdapterState.NetAdapter | Where-Object InterfaceDescription -eq $thisInterfaceDescription).Name | Should Be $thisCfgVMSwitch.RDMAEnabledAdapters.Name
                        }
                    }

                    $true {
                        ### Verify SET contains the expected number of adapters
                        It "[SUT: $nodeName]-[VMSwitch: $($thisCfgVMSwitch.Name)]-[Noun: VMSwitch] vSwitch contains ($($thisCfgVMSwitch.RDMAEnabledAdapters.Count)) adapters" {
                            ($actvmSwitch.vmSwitch | Where-Object Name -eq $thisCfgVMSwitch.Name).NetAdapterInterfaceDescriptions.Count | Should Be $thisCfgVMSwitch.RDMAEnabledAdapters.Count
                        }
                        
                        ### Verify LBFO Multiplexor is not used
                        It "[SUT: $nodeName]-[VMSwitch: $($thisCfgVMSwitch.Name)]-[Noun: VMSwitch] vSwitch should not use LBFO Teaming" {
                            ($actvmSwitch.vmSwitch | Where-Object Name -eq $thisCfgVMSwitch.Name).NetAdapterInterfaceDescription | Should Not Be 'Microsoft Network Adapter Multiplexor Driver'
                        }

                        ### Verify the vSwitch is a teamed interface (implies SET based on the previous test)
                        It "[SUT: $nodeName]-[VMSwitch: $($thisCfgVMSwitch.Name)]-[Noun: VMSwitch] vSwitch should be a teamed interface" {
                            ($actvmSwitch.vmSwitch | Where-Object Name -eq $thisCfgVMSwitch.Name).NetAdapterInterfaceDescription | Should Be 'Teamed-Interface'
                        }
                        
                        foreach ($thisRDMAEnabledAdapter in $thisCfgVMSwitch.RDMAEnabledAdapters) {
                            ### Verify the expected phyiscal adapters are part of the team
                            It "[SUT: $nodeName]-[VMSwitch: $($thisCfgVMSwitch.Name)]-[RDMAEnabledAdapter: $($thisRDMAEnabledAdapter.Name)]-[Noun: VMSwitchTeam] Interface should be a member of the SET team" {
                                ($actvmSwitch.vmSwitchTeam | Where-Object Name -eq $thisCfgVMSwitch.Name).NetAdapterInterfaceDescription -contains 
                                ($actNetAdapterState.NetAdapter | Where-Object Name -eq $thisRDMAEnabledAdapter.Name).InterfaceDescription | Should be $true
                            }
                        }

                        ### Verify adapters in the team are symmetric: DriverFileName
                        It "[SUT: $nodeName]-[VMSwitch: $($thisCfgVMSwitch.Name)]-[Noun: NetAdapter] Adapters in the team are symmetric [same DriverFileName]" {
                            (($actNetAdapterState.NetAdapter).DriverName | Select-Object -Unique).Count | Should be 1
                        }

                        ### Verify adapters in the team are symmetric: DriverVersion
                        It "[SUT: $nodeName]-[VMSwitch: $($thisCfgVMSwitch.Name)]-[Noun: NetAdapter] Adapters in the team are symmetric [same DriverVersion]" {
                            (($actNetAdapterState.NetAdapter).DriverVersion | Select-Object -Unique).Count | Should be 1
                        }

                        ### Verify the team is SwitchIndependent (Currently the only option but -- Future Proofing)
                        It "[SUT: $nodeName]-[VMSwitch: $($thisCfgVMSwitch.Name)]-[Noun: VMSwitchTeam] TeamingMode must be SwitchIndependent" {
                            ($actvmSwitch.vmSwitchTeam | Where-Object Name -eq $thisCfgVMSwitch.Name).TeamingMode | Should Be 'SwitchIndependent'
                        }

                        ### Verify the load balancing algorithm is the expected.  Either setting is acceptable; testing for consistency
                        If ($thisCfgVMSwitch.LoadBalancingAlgorithm) {
                            It "[SUT: $nodeName]-[VMSwitch: $($thisCfgVMSwitch.Name)]-[Noun: VMSwitchTeam] LoadBalancingAlgorithm must be $($thisCfgVMSwitch.LoadBalancingAlgorithm)" {
                                ($actvmSwitch.vmSwitchTeam | Where-Object Name -eq $thisCfgVMSwitch.Name).LoadBalancingAlgorithm | Should Be $thisCfgVMSwitch.LoadBalancingAlgorithm
                            }
                        }

                        ### Verify PacketDirect is disabled (not required for RDMA; best practice for VMSwitch)
                        It "[SUT: $nodeName]-[VMSwitch: $($thisCfgVMSwitch.Name)]-[Noun: VMSwitch] PacketDirect must be Disabled" {
                            ($actvmSwitch.vmSwitch | Where-Object Name -eq $thisCfgVMSwitch.Name).PacketDirectEnabled | Should Be $false
                        }
                    }
    
                    ### Verify no catastrophic failures in the VMSwitch testing...
                    default { It "Could not determine the EmbeddedTeamingEnabled configuration" { $false | Should be $true }}
                }

                Switch ($thisCfgVMSwitch.IovEnabled) {
                    $false {
                        ### Verify the VMSwitch has disabled SR-IOV (e.g. No Guest RDMA possible)
                        It "[SUT: $nodeName]-[VMSwitch: $($thisCfgVMSwitch.Name)]-[Noun: VMSwitch] The VMSwitch should have SR-IOV disabled" {
                            ($actvmSwitch.vmSwitch | Where-Object Name -eq $thisCfgVMSwitch.Name).IovEnabled | Should Be $false
                        }
                    }

                    $true {
                        foreach ($thisRDMAEnabledAdapter in $thisCfgVMSwitch.RDMAEnabledAdapters) {
                            ### Verify the expected phyiscal adapters have SR-IOV enabled
                            It "[SUT: $nodeName]-[VMSwitch: $($thisCfgVMSwitch.Name)]-[RDMAEnabledAdapter: $($thisRDMAEnabledAdapter.Name)]-[Noun: NetAdapterSRIOV] Interface should report SR-IOV is supported" {
                                ($actvmSwitch.NetAdapterSRIOV | Where-Object Name -eq $thisRDMAEnabledAdapter.Name).Enabled | Should be $true

                                # If support is disabled, review for potential reasons https://docs.microsoft.com/en-us/powershell/module/netadapter/get-netadaptersriov?view=win10-ps
                            }

                            It "[SUT: $nodeName]-[VMSwitch: $($thisCfgVMSwitch.Name)]-[RDMAEnabledAdapter: $($thisRDMAEnabledAdapter.Name)]-[Noun: NetAdapterSRIOV] Interface should have at least 1 VF" {
                                ($actvmSwitch.NetAdapterSRIOV | Where-Object Name -eq $thisRDMAEnabledAdapter.Name).NumVFs | Should BeGreaterThan 0
                            }
                        }

                        ### Verify IOV is supported by the VMSwitch (Summary of the Adapters)
                        It "[SUT: $nodeName]-[VMSwitch: $($thisCfgVMSwitch.Name)]-[Noun: VMSwitch] The VMSwitch should support SR-IOV" {
                            ($actvmSwitch.vmSwitch | Where-Object Name -eq $thisCfgVMSwitch.Name).IovSupport | Should Be $true
                        }
                        
                        ### Verify the VMSwitch has SR-IOV Enabled
                        It "[SUT: $nodeName]-[VMSwitch: $($thisCfgVMSwitch.Name)]-[Noun: VMSwitch] The VMSwitch should have SR-IOV enabled" {
                            ($actvmSwitch.vmSwitch | Where-Object Name -eq $thisCfgVMSwitch.Name).IovEnabled | Should Be $true
                        }

                        ### Verify the VMSwitch has at least one Iov Queue Pair
                        It "[SUT: $nodeName]-[VMSwitch: $($thisCfgVMSwitch.Name)]-[Noun: VMSwitch] The VMSwitch's IovQueuePairCount must be at least 1" {
                            ($actvmSwitch.vmSwitch | Where-Object Name -eq $thisCfgVMSwitch.Name).IovQueuePairCount | Should BeGreaterThan 0
                        }

                        ### Verify the VMSwitch has at least 1 Virtual Function to hand out
                        It "[SUT: $nodeName]-[VMSwitch: $($thisCfgVMSwitch.Name)]-[Noun: VMSwitch] The VMSwitch's IovVirtualFunctionCount must be at least 1" {
                            ($actvmSwitch.vmSwitch | Where-Object Name -eq $thisCfgVMSwitch.Name).IovVirtualFunctionCount | Should BeGreaterThan 0
                        }
                    }
                }
            }

            foreach ($thisRDMAEnabledAdapter in $thisCfgVMSwitch.RDMAEnabledAdapters) {
                $VMNetworkAdapter = @()
                $VMNetworkAdapterTeamMapping = @()

                $VMNetworkAdapter            = Get-VMNetworkAdapter            -Name $thisRDMAEnabledAdapter.VMNetworkAdapter -ManagementOS -CimSession $nodeName -ErrorAction SilentlyContinue
                $VMNetworkAdapterTeamMapping = Get-VMNetworkAdapterTeamMapping -Name $thisRDMAEnabledAdapter.VMNetworkAdapter -ManagementOS -CimSession $nodeName -ErrorAction SilentlyContinue
            
                $NetAdapter = @()
                $NetAdapterRDMA = @()
                $netAdapterAdvancedProperty = @()

                If ($VMNetworkAdapter.Name -eq $thisRDMAEnabledAdapter.VMNetworkAdapter) {
                    $NetAdapter     = Get-NetAdapter -CimSession $nodeName -ErrorAction SilentlyContinue | Where-Object DeviceID -eq $VMNetworkAdapter.DeviceID
                    $NetAdapterRDMA = Get-NetAdapterRDMA -Name $NetAdapter.Name -CimSession $nodeName -ErrorAction SilentlyContinue
                    $NetAdapterAdvancedProperty = Get-NetAdapterAdvancedProperty -Name $NetAdapter.Name -CimSession $nodeName -ErrorAction SilentlyContinue
                }

                $actvmSwitch.NetAdapter                  = $NetAdapter
                $actvmSwitch.NetAdapterRDMA              = $NetAdapterRDMA
                $actvmSwitch.NetAdapterAdvancedProperty  = $NetAdapterAdvancedProperty
                $actvmSwitch.VMNetworkAdapter            = $VMNetworkAdapter
                $actvmSwitch.VMNetworkAdapterTeamMapping = $VMNetworkAdapterTeamMapping

                Remove-Variable -Name NetAdapter, NetAdapterRDMA, NetAdapterAdvancedProperty, VMNetworkAdapter, VMNetworkAdapterTeamMapping -ErrorAction SilentlyContinue
            
                Context "[Modal Unit]-[VMSwitch: $($thisCfgVMSwitch.Name)]-[VMNetworkAdapter: $($thisRDMAEnabledAdapter.VMNetworkAdapter)]-[SUT: $nodeName]-Virtual NICs NetAdapter and NetAdapterAdvancedProperty Settings" {
                    ### Verify the virtual NIC's NetAdapter Name is the same as the VMNetworkAdapter name
                    It "[SUT: $nodeName]-[VMSwitch: $($thisCfgVMSwitch.Name)]-[RDMAEnabledAdapter: $($thisRDMAEnabledAdapter.Name)]-[VMNetworkAdapter: $($thisRDMAEnabledAdapter.VMNetworkAdapter)]-[Noun: NetAdapter, VMNetworkAdapter] NetAdapter Name for the virtual NIC is named the same as the VMNetworkAdapter name" {
                        ($actvmSwitch.NetAdapter | Where-Object Name -eq $thisRDMAEnabledAdapter.VMNetworkAdapter).Name | Should be $thisRDMAEnabledAdapter.VMNetworkAdapter
                    }

                    ### Verify the interface is a virtual interface
                    It "[SUT: $nodeName]-[VMSwitch: $($thisCfgVMSwitch.Name)]-[RDMAEnabledAdapter: $($thisRDMAEnabledAdapter.Name)]-[VMNetworkAdapter: $($thisRDMAEnabledAdapter.VMNetworkAdapter)]-[Noun: NetAdapter] The interface must be virtual" {
                        ($actvmSwitch.NetAdapter | Where-Object Name -eq $thisRDMAEnabledAdapter.VMNetworkAdapter).ConnectorPresent | Should Be $false
                    }

                    ### Verify the interface is enabled
                    It "[SUT: $nodeName]-[VMSwitch: $($thisCfgVMSwitch.Name)]-[RDMAEnabledAdapter: $($thisRDMAEnabledAdapter.Name)]-[VMNetworkAdapter: $($thisRDMAEnabledAdapter.VMNetworkAdapter)]-[Noun: NetAdapter] The virtual interface status must be `"Up`"" {
                        ($actvmSwitch.NetAdapter | Where-Object Name -eq $thisRDMAEnabledAdapter.VMNetworkAdapter).Status | Should Be 'Up'
                    }

                    ### Verify the interface has media link
                    It "[SUT: $nodeName]-[VMSwitch: $($thisCfgVMSwitch.Name)]-[RDMAEnabledAdapter: $($thisRDMAEnabledAdapter.Name)]-[VMNetworkAdapter: $($thisRDMAEnabledAdapter.VMNetworkAdapter)]-[Noun: NetAdapter] The virtual interface media state must be `"Connected`"" {
                        ($actvmSwitch.NetAdapter | Where-Object Name -eq $thisRDMAEnabledAdapter.VMNetworkAdapter).MediaConnectionState | Should Be 'Connected'
                    }

                    If ($thisRDMAEnabledAdapter.JumboPacket) {
                        ### Verify if the JumboPacket param is specified in the cfg file, that the vNIC also has the jumbo frame setting
                        It "[SUT: $nodeName]-[VMSwitch: $($thisCfgVMSwitch.Name)]-[RDMAEnabledAdapter: $($thisRDMAEnabledAdapter.Name)]-[VMNetworkAdapter: $($thisRDMAEnabledAdapter.VMNetworkAdapter)]-[Noun: NetAdapterAdvancedProperty] should have Jumbo Frames set to [$($thisRDMAEnabledAdapter.JumboPacket)]" {
                            ($actvmSwitch.NetAdapterAdvancedProperty | Where-Object{$_.Name -eq $thisRDMAEnabledAdapter.VMNetworkAdapter -and $_.RegistryKeyword -eq '*JumboPacket'}).RegistryValue | Should Be $thisRDMAEnabledAdapter.JumboPacket
                        }
                    }

                    ### Verify Interface is RDMA Capable (includes the *NetworkDirect Keyword)
                    It "[SUT: $nodeName]-[VMSwitch: $($thisCfgVMSwitch.Name)]-[RDMAEnabledAdapter: $($thisRDMAEnabledAdapter.Name)]-[VMNetworkAdapter: $($thisRDMAEnabledAdapter.VMNetworkAdapter)]-[Noun: NetAdapterAdvancedProperty] should be NetworkDirect (RDMA) capable" {
                        $actvmSwitch.netAdapterAdvancedProperty | Where-Object{$_.Name -eq $thisRDMAEnabledAdapter.VMNetworkAdapter -and $_.RegistryKeyword -eq '*NetworkDirect'} | Should Not BeNullOrEmpty
                    }

                    ### Verify the NetAdapter is Enabled for RDMA
                    It "[SUT: $nodeName]-[VMSwitch: $($thisCfgVMSwitch.Name)]-[RDMAEnabledAdapter: $($thisRDMAEnabledAdapter.Name)]-[VMNetworkAdapter: $($thisRDMAEnabledAdapter.VMNetworkAdapter)]-[Noun: NetAdapterRDMA] VMNetworkAdapter should be enabled for RDMA" {
                        ($actvmSwitch.NetAdapterRDMA | Where-Object Name -eq $thisRDMAEnabledAdapter.VMNetworkAdapter).Enabled | Should be $true
                    }
                }

                Context "[Modal Unit]-[VMSwitch: $($thisCfgVMSwitch.Name)]-[SUT: $nodeName]-VMNetworkAdapter Settings" {
                    ### Verify the VMNetworkAdapter specified in the config file exists
                    It "[SUT: $nodeName]-[VMSwitch: $($thisCfgVMSwitch.Name)]-[RDMAEnabledAdapter: $($thisRDMAEnabledAdapter.Name)]-[VMNetworkAdapter: $($thisRDMAEnabledAdapter.VMNetworkAdapter)]-[Noun: VMNetworkAdapter] VMNetworkAdapter should exist" {
                        (($actvmSwitch.VMNetworkAdapter).Name -contains $thisRDMAEnabledAdapter.VMNetworkAdapter) | Should be $true
                    }

                    ### Verify the VMNetworkAdapter Status is OK
                    It "[SUT: $nodeName]-[VMSwitch: $($thisCfgVMSwitch.Name)]-[RDMAEnabledAdapter: $($thisRDMAEnabledAdapter.Name)]-[VMNetworkAdapter: $($thisRDMAEnabledAdapter.VMNetworkAdapter)]-[Noun: VMNetworkAdapter] VMNetworkAdapter Status should be 'OK'" {
                        ($actvmSwitch.VMNetworkAdapter | Where-Object Name -eq $thisRDMAEnabledAdapter.VMNetworkAdapter).Status | Should be 'Ok'
                    }

                    ### Verify the VMNetworkAdapter is attached to the VMSwitch
                    It "[SUT: $nodeName]-[VMSwitch: $($thisCfgVMSwitch.Name)]-[RDMAEnabledAdapter: $($thisRDMAEnabledAdapter.Name)]-[VMNetworkAdapter: $($thisRDMAEnabledAdapter.VMNetworkAdapter)]-[Noun: VMNetworkAdapter] VMNetworkAdapter should be connected to the VMSwitch" {
                        ($actvmSwitch.VMNetworkAdapter | Where-Object Name -eq $thisRDMAEnabledAdapter.VMNetworkAdapter).SwitchName | Should be $thisCfgVMSwitch.Name
                    }

                    ### Verify the VMNetwork adapter is mapped to the specified pNIC
                    If ($thisCfgVMSwitch.EmbeddedTeamingEnabled -eq $true) {
                        It "[SUT: $nodeName]-[VMSwitch: $($thisCfgVMSwitch.Name)]-[RDMAEnabledAdapter: $($thisRDMAEnabledAdapter.Name)]-[VMNetworkAdapterTeamMapping: $($thisRDMAEnabledAdapter.VMNetworkAdapter)]-[Noun: VMNetworkAdapterTeamMapping] VMNetworkAdapter should be mapped to the physical adapter" {
                            ($actvmSwitch.VMNetworkAdapterTeamMapping | Where-Object NetAdapterName -eq $thisRDMAEnabledAdapter.Name).ParentAdapter.Name | Should be $thisRDMAEnabledAdapter.VMNetworkAdapter

                        }
                    }
                }
            }
        }
    }
}
