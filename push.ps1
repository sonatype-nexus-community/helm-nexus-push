[CmdletBinding(PositionalBinding = $false)] # ensures that any parameters not explicitly marked with a Position property must be passed as named arguments (i.e., the argument must be preceded by the name of the target parameter, e.g. -Path foo).
param(
    [Parameter()]
    [Alias("u")]
    [string]$username,
 
    [Parameter()]
    [Alias("p")]
    [string]$password,

    [Parameter(ValueFromRemainingArguments)]
    [string]$params
)
 
function Usage() {
    Write-Output "	
Push Helm Chart to Nexus repository

This plugin provides ability to push a Helm Chart directory or package to a remote Nexus Helm repository.

Usage:
  helm nexus-push [repo] login [flags]        Setup login information for repo
  helm nexus-push [repo] logout [flags]       Remove login information for repo
  helm nexus-push [repo] [CHART] [flags]      Pushes chart to repo

Flags:
  -u, -username string                 Username for authenticated repo (assumes anonymous access if unspecified)
  -p, -password string                 Password for authenticated repo (prompts if unspecified and -u specified)

Examples:
  To save credentials
  helm nexus-push nexus login -u username -p password  
  
  To delete credentials
  helm nexus-push nexus logout
  
  To push the chart using saved credentials
  helm nexus-push nexus . 

  To push the chart with credentials
  helm nexus-push nexus .  -u username -p password
"

}

# need at least params not empty
if ($PSBoundParameters.Count -eq 0 -Or [string]::IsNullOrEmpty($params)) {
    Usage
    exit(1)
}

# check if the help command was received
if($params -eq "--help"){
    Usage
    exit(0)
}

# need a password if the username is specified
if ($username -And [string]::IsNullOrEmpty($password)) {
    Usage
    exit(1)
}

# convert params to array
$PARAMS_ARRAY = $params.Split(" ")
$REPO_NAME = $($PARAMS_ARRAY[0])
$COMMAND_OR_PATH = $($PARAMS_ARRAY[1])

# Credential file
$REPO_AUTH_FILE = $($env:HELM_DATA_HOME + "\auth." + $REPO_NAME)

$REPO_LIST = $(helm repo list -o json) | ConvertFrom-Json
$REPO_JSON = $REPO_LIST | Where-Object { $_.name -eq $REPO_NAME }

if (!$REPO_JSON) {
    Write-Output "Repository not found, please validate that you added the repository to Helm with the command [helm repo list]"
    exit(2)
}

# check if the command is (login/logout) or the chart folder
if ($COMMAND_OR_PATH -eq "login") {
    Write-Output "Writing crendentials in file [$REPO_AUTH_FILE]"
    "$($username):$($password)" | Out-File -FilePath $REPO_AUTH_FILE
} elseif ($COMMAND_OR_PATH -eq "logout") {
    Write-Output "Deleting crendentials file [$REPO_AUTH_FILE]"
    if (test-path $REPO_AUTH_FILE) {
        Remove-Item $REPO_AUTH_FILE
    }
} else {
    # Package the chart to a temporay folder
    $HELM_PACKAGE_OUTPUT=$(helm package $COMMAND_OR_PATH -d $ENV:Temp)

    # Find output file path
    $HELM_PACKAGE_FILE=$($HELM_PACKAGE_OUTPUT.substring($HELM_PACKAGE_OUTPUT.IndexOf(":")+1).trim())
    
    $CREDENTIALS = ""
    # find credentials
    if (!$username) {
        # load the credential file if present (login)
        if (test-path $REPO_AUTH_FILE) {
            $CREDENTIALS = Get-Content $REPO_AUTH_FILE -Raw
            $CREDENTIALS=$CREDENTIALS.trim()
        }
    } else {
        $CREDENTIALS = "$($username):$($password)"
    }

    # Find the repository URL
    $REPO_URL = $REPO_JSON.url

    # Push the chart
    Write-Output "Pushing chart[$HELM_PACKAGE_FILE] to repository [$REPO_URL]"
    if ([string]::IsNullOrEmpty($CREDENTIALS)) {
        $response=$(curl.exe -is "$REPO_URL" --upload-file "$HELM_PACKAGE_FILE")
    } else {
        $response=$(curl.exe -is -u "$CREDENTIALS" "$REPO_URL" --upload-file "$HELM_PACKAGE_FILE")
    }

    # delete chart package
    Remove-Item $HELM_PACKAGE_FILE

    # check that the response was a "200 OK"
    if(!$($response|select-string -Pattern "200 OK")){
        Write-Output "There was a error while pushing the chart, here the output logs"
        foreach($line in $response){
            Write-Host $line
        }
        exit(3)
    }

    Write-Output "Done"
    exit(0)
}
