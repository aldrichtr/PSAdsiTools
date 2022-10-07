function Format-PrtgXmlSensorOutput {
    <#
        .SYNOPSIS
        Assemble the complete output for a PRTG XML sensor
        .DESCRIPTION
        Combine multiple channels into a single PRTG XML sensor result
        .INPUTS
        [System.String]$PrtgXmlResult
        .OUTPUTS
        [System.String] Complete XML output for a PRTG custom XML sensor
        .EXAMPLE
        @"
        <result>
        <channel>Channel123</channel>
        <value>Value123</value>
        <unit>Custom</unit>
        <customUnit>Miles Per Hour</customUnit>
        <showchart>$ShowChart</showchart>
        </result>
        @" |
        New-PrtgXmlSensorOutput

        Generate XML output for a PRTG sensor that will put it in an OK state
        .EXAMPLE
        @"
        <result>
        <channel>Channel123</channel>
        <value>Value123</value>
        <unit>Custom</unit>
        <customUnit>Miles Per Hour</customUnit>
        <showchart>0</showchart>
        </result>
        @" |
        New-PrtgXmlSensorOutput -IssueDetected

        Generate XML output for a PRTG sensor that will put it in an alarm state
    #>

    param (

        # Valid XML for a PRTG result for a single channel
        # Can be created by Format-PrtgXmlResult
        [Parameter(ValueFromPipeline)]
        [string[]]$PrtgXmlResult,

        # Force the PRTG sensor into an alarm state
        [switch]$IssueDetected

    )

    begin {
        $Strings = [System.Collections.Generic.List[string]]::new()
        $null = $Strings.add("<prtg>")
    }
    process {
        foreach ($XmlResult in $PrtgXmlResult) {
            $null = $Strings.add($XmlResult)
        }
    }
    end {
        if ($IssueDetected) {
            $null = $Strings.add("<text>Issue detected, see sensor channels for details</text>")
        } else {
            $null = $Strings.add("<text>OK</text>")
        }
        $null = $Strings.add("</prtg>")
        $Strings
    }
}
