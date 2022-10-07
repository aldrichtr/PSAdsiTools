function Send-PrtgXmlSensorOutput {

    <#
        .SYNOPSIS
        Wrapper for Invoke-WebRequest to make it easy to push results to PRTG XML push sensors
        .DESCRIPTION
        Use HTTP post to post results to PRTG XML push sensors
        .INPUTS
        [System.String]$XmlOutput
        .OUTPUTS
        Passes through the output of Invoke-WebRequest
        .EXAMPLE
        New-PrtgXmlSensorOutput ... |
        Send-PrtgXmlSensorOutput -PrtgSensorProtocol 'https' -PrtgProbe 'server1' -PrtgSensorPort 443 -PrtgSensorToken 'e3edd633-3018-4d8a-91b6-d2635b42b85b'

        Post sensor output to PRTG push sensor e3edd633-3018-4d8a-91b6-d2635b42b85b on server1 using HTTPS on TCP port 443
    #>

    param(

        # Valid XML for a PRTG custom XML sensor
        # Can be created by Format-PrtgXmlSensorOutput
        [string]$XmlOutput,

        # If all four of the PRTG parameters are specified, then the results will be XML-formatted and pushed to the specified PRTG probe for a push sensor
        [string]$PrtgProbe,

        # If all four of the PRTG parameters are specified, then the results will be XML-formatted and pushed to the specified PRTG probe for a push sensor
        [string]$PrtgSensorProtocol,

        # If all four of the PRTG parameters are specified, then the results will be XML-formatted and pushed to the specified PRTG probe for a push sensor
        [int]$PrtgSensorPort,

        # If all four of the PRTG parameters are specified, then the results will be XML-formatted and pushed to the specified PRTG probe for a push sensor
        [string]$PrtgSensorToken
    )

    $ResultToPost = @{
        Body            = $XMLOutput
        ContentType     = 'application/xml'
        Method          = 'Post'
        Uri             = "$PrtgSensorProtocol`://$PrtgProbe`:$PrtgSensorPort/$PrtgSensorToken"
        UseBasicParsing = $true
    }

    if ($PrtgSensorToken) {
        Write-Verbose "URI: $PrtgSensorProtocol`://$PrtgProbe`:$PrtgSensorPort/$PrtgSensorToken"

        Invoke-WebRequest @ResultToPost
    }

}
