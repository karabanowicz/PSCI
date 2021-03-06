function Test-ProcessBlockImplemented
{
    #region     ScriptTokenValidation Parameter Statement
    param(
    <#    
    This parameter will contain the tokens in the script, and will be automatically 
    provided when this command is run within ScriptCop.
    
    This parameter should not be used directly, except for testing purposes.        
    #>
    [Parameter(ParameterSetName='TestScriptToken',
        Mandatory=$true,
        ValueFromPipelineByPropertyName=$true)]
    [Management.Automation.PSToken[]]
    $ScriptToken,
    
    <#   
    This parameter will contain the command that was tokenized, and will be automatically
    provided when this command is run within ScriptCop.
    
    This parameter should not be used directly, except for testing purposes.
    #>
    [Parameter(ParameterSetName='TestScriptToken',Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
    [Management.Automation.CommandInfo]
    $ScriptTokenCommand,
    
    <#
    This parameter contains the raw text of the script, and will be automatically
    provided when this command is run within ScriptCop
    
    This parameter should not be used directly, except for testing purposes.    
    #>
    [Parameter(ParameterSetName='TestScriptToken',Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
    [string]
    $ScriptText
    )
    #endregion  ScriptTokenValidation Parameter Statement
    
    begin {
        function Get-CommandWithPipelineParameter
        {
            [CmdletBinding(DefaultParameterSetName="All")]            
            param(
            [Parameter(Mandatory=$true,
                ParameterSetName="Command",
                ValueFromPipeline=$true)]
            [Management.Automation.CommandInfo]
            $command
            )
            
            process {                
                switch ($psCmdlet.ParameterSetName) {
                    All {$cmds = Get-Command } 
                    Command { $cmds = $command } 
                }
                $cmds | Where-Object { 
                    $_.Parameters.Values | 
                    Where-Object {
                        $_.ParameterSets.Values | 
                            Where-Object {
                                $_.ValueFromPipelineByPropertyName -or 
                                $_.ValueFromPipeline
                            }
                    }
                }
            }
        }        
    }
    
    process {              
        $hasPipelineParameters = $ScriptTokenCommand | Get-CommandWithPipelineParameter
        if (-not $hasPipelineParameters) { return }
        
        $processToken = $ScriptToken |
            Where-Object { $_.Type -eq "Keyword" -and $_.Content -eq "process" }
        
        if (-not $processToken) {
            Write-Error "$ScriptTokenCommand can take values from the pipeline, but has no process block"
            return
        }
    }
} 
