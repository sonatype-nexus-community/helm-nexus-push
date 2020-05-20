Add-Type -AssemblyName System.Net.Http

$globalArgs = New-Object "System.Collections.ArrayList"
$USERNAME
$PASSWORD

while ($args.Length -gt 0) {
    switch ($args[0]) {
        "-h" {}
        "--help" {}
        "-u" {
            if (!$args[1]) {
                Write-Host "Must specify username!`n---"
                exit 1
            }
            $null, $args = $args
            if ($args.Count -eq 1) {
                $USERNAME = $args
            } else {
                $USERNAME = $args[0]
            }
            Break
        }
        "--username" {
            if (!$args[1]) {
                Write-Host "Must specify username!`n---"
                exit 1
            }
            $null, $args = $args
            if ($args.Count -eq 1) {
                $USERNAME = $args
            } else {
                $USERNAME = $args[0]
            }
            Break
        }
        "-p" {
            if ($args[1]) {
                $null, $args = $args
                if ($args.Count -eq 1) {
                    $PASSWORD = $args
                } else {
                    $PASSWORD = $args[0]
                }
            } else {
                $PASSWORD = ""
            }
            Break
        }
        "--password" {
            if ($args[1]) {
                $null, $args = $args
                if ($args.Count -eq 1) {
                    $PASSWORD = $args
                } else {
                    $PASSWORD = $args[0]
                }
            } else {
                $PASSWORD = ""
            }
            Break
        }
        default {
            if($args.Count -eq 1) {
                $null = $globalArgs.Add($args)
            } else {
                $null = $globalArgs.Add($args[0])
            }
        }
    }
    $null, $args = $args
}

if ($globalArgs.Count -lt 2 ) {
    Write-Host "Missing Arguments`n---"
    exit 1
}

$HELM3_VERSION=(helm version --client --short | Select-String "v3\." | %{$_.Line.Trim()})

$REPO=$globalArgs[0]
$REPO_URL=(helm repo list | Select-String $REPO | %{ [regex]::split($_.Line," +")[1].trim(); })

if ($HELM3_VERSION) {
    $REPO_AUTH_FILE="$env:APPDATA\helm\auth.$REPO"
} else {
    $REPO_AUTH_FILE="$env:APPDATA\helm\auth.$REPO"
}

if(!$REPO_URL) {
    Write-Host "Invalid repo specified!  Must specify one of these repos..."
    helm repo list
    Write-Host "---"
    exit 1
}


switch ($globalArgs[1]) {
    "login" {
        if(!$USERNAME) {
            $USERNAME = Read-Host -Prompt "Username"
        }
        if(!$PASSWORD) {
            $PASSWORD = Read-Host -Prompt "Password" -AsSecureString 
            $PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($PASSWORD))
        }
        echo ${USERNAME}:${PASSWORD} > $REPO_AUTH_FILE
        Break
    }
    "logout" {
        try {
            Remove-Item $REPO_AUTH_FILE -Force -ErrorAction Stop 
            Write-Host "Logged Out Successfully!"
        } catch {
            Write-Host "Unable to logout"
        }
        Break
    }
    default {
        $CHART = $globalArgs[1]
        if (!$USERNAME -or !$PASSWORD) {
            if($REPO_AUTH_FILE -and (Test-Path $REPO_AUTH_FILE)) {
                $item = Get-Item $REPO_AUTH_FILE
                if(!$item.PSisContainer) {
                    Write-Host "Using cached login creds..."
                    $AUTH=(Get-Content $REPO_AUTH_FILE)
                } else {
                    if(!$USERNAME) {
                        $USERNAME = Read-Host -Prompt "Username"
                    }
                    if(!$PASSWORD) {
                        $PASSWORD = Read-Host -Prompt "Password" -AsSecureString 
                        $PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($PASSWORD))
                    }
                    $AUTH = "${USERNAME}:${PASSWORD}"
                }
            }
        } else {
            $AUTH = "${USERNAME}:${PASSWORD}"
        }
        if($CHART -and (Test-Path $CHART)) {
            $item = Get-Item $CHART
            if($item.PSisContainer) {
                Write-Host "Packaging Chart..."
                $CHART_PACKAGE = (helm package "$CHART").split("\")[-1]
            } else {
                $CHART_PACKAGE = $CHART.replace(".\","")
            }
        }
        $REPO_URL += "/${CHART_PACKAGE}"
        Write-Host "Pushing $CHART to repo $REPO_URL..."
        $bytes = [System.Text.Encoding]::ASCII.GetBytes($AUTH)
        $base64 = [System.Convert]::ToBase64String($bytes)
        $basicAuthValue = "Basic $base64"
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $headers.Add("Authorization", $basicAuthValue )
        $headers.Add("Content-Type", "application/octet-stream")
        try {
            $response = (Invoke-WebRequest $REPO_URL -Method 'PUT' -Headers $headers -InFile $CHART_PACKAGE)
            Write-Host "Pushed successfully!"
        } catch {
            Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__ 
            Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
        }
    }
}

exit 0