#!/usr/bin/env bash

set -ueo pipefail

usage() {
cat << EOF
Push Helm Chart to Nexus repository

This plugin provides ability to push a Helm Chart directory or package to a
remote Nexus Helm repository.

Usage:
  helm nexus-push [repo] login [flags]        Setup login information for repo
  helm nexus-push [repo] logout [flags]       Remove login information for repo
  helm nexus-push [repo] delete [flags]       Remove chart from repo
  helm nexus-push [repo] [CHART] [flags]      Pushes chart to repo

Flags:
  -u, --username string                 Username for authenticated repo (assumes anonymous access if unspecified)
  -p, --password string                 Password for authenticated repo (prompts if unspecified and -u specified)
  -d, --filename string                 Artifact filename (used to delete a specific version in the repository)

Examples:
  To save credentials
  helm nexus-push nexus login -u username -p password  
  
  To delete credentials
  helm nexus-push nexus logout
  
  To push the chart using saved credentials
  helm nexus-push nexus . 

  To push the chart with credentials
  helm nexus-push nexus .  -u username -p password

  To delete chart from repository
  helm nexus-push nexus delete .

  To delete chart from repository
  helm nexus-push nexus delete -d artifact-1.0.0.tgz  
EOF
}

declare USERNAME=""
declare PASSWORD=""
declare FILENAME=""

declare -a POSITIONAL_ARGS=()
while [[ $# -gt 0 ]]
do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -u|--username)
            if [[ -z "${2:-}" ]]; then
                echo "Must specify username!"
                echo "---"
                usage
                exit 1
            fi
            shift
            USERNAME=$1
            ;;
        -p|--password)
            if [[ -n "${2:-}" ]]; then
                shift
                PASSWORD=$1
            else
                PASSWORD=
            fi
            ;;
        -d|--filename)
            if [[ -n "${2:-}" ]]; then
                shift
                FILENAME=$1
            else
                FILENAME=
            fi
            ;;
        *)
            POSITIONAL_ARGS+=("$1")
            ;;
   esac
   shift
done
[[ ${#POSITIONAL_ARGS[@]} -ne 0 ]] && set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

if [[ $# -lt 2 ]]; then
  echo "Missing arguments!"
  echo "---"
  usage
  exit 1
fi

indent() { sed 's/^/  /'; }

getCredendials(){
    if [[ -z "$USERNAME" ]] || [[ -z "$PASSWORD" ]]; then
        if [[ -f "$REPO_AUTH_FILE" ]]; then
            echo "Using cached login creds..."
            AUTH="$(cat $REPO_AUTH_FILE)"
        else
            if [[ -z "$USERNAME" ]]; then
                read -p "Username: " USERNAME
            fi
            if [[ -z "$PASSWORD" ]]; then
                read -s -p "Password: " PASSWORD
                echo
            fi
            AUTH="$USERNAME:$PASSWORD"
        fi
    else
            AUTH="$USERNAME:$PASSWORD"
    fi
}

declare HELM3_VERSION="$(helm version --client --short | grep "v3\.")"

declare REPO=$1
declare REPO_URL="$(helm repo list | grep "^$REPO" | awk '{print $2}')/"

if [[ -n $HELM3_VERSION ]]; then
declare REPO_AUTH_FILE="$HOME/.config/helm/auth.$REPO"
else
declare REPO_AUTH_FILE="$(helm home)/repository/auth.$REPO"
fi

if [[ -z "$REPO_URL" ]]; then
    echo "Invalid repo specified!  Must specify one of these repos..."
    helm repo list
    echo "---"
    usage
    exit 1
fi

declare CMD
declare AUTH
declare CHART

case "$2" in
    login)
        if [[ -z "$USERNAME" ]]; then
            read -p "Username: " USERNAME
        fi
        if [[ -z "$PASSWORD" ]]; then
            read -s -p "Password: " PASSWORD
            echo
        fi
        echo "$USERNAME:$PASSWORD" > "$REPO_AUTH_FILE"
        ;;
    logout)
        rm -f "$REPO_AUTH_FILE"
        ;;
    delete)
        # find credentials
        getCredendials

        CMD=delete

        if [[ -z "$FILENAME" ]]; then
            CHART=$3
            CHART_PACKAGE="$(helm package "$CHART" | cut -d ":" -f2 | xargs)"
        else
            CHART_PACKAGE="$FILENAME"
        fi
        
        # get package filename without path
        CHART_PACKAGE=$(basename $CHART_PACKAGE)

        echo "Deleting [$CHART_PACKAGE] from repo [$REPO_URL]..."
        curl --request DELETE -is -u "$AUTH" "$REPO_URL$CHART_PACKAGE" | indent
        rm -rf "$CHART_PACKAGE"
        echo "Done"
        ;;
    *)
        CMD=push
        CHART=$2

        # find credentials
        getCredendials

        if [[ -d "$CHART" ]]; then
            CHART_PACKAGE="$(helm package "$CHART" | cut -d ":" -f2 | xargs)"
        else
            CHART_PACKAGE="$CHART"
        fi

        echo "Pushing [$CHART] to repo [$REPO_URL]..."
        curl -is -u "$AUTH" "$REPO_URL" --upload-file "$CHART_PACKAGE" | indent
        rm -rf "$CHART_PACKAGE"
        echo "Done"
        ;;
esac

exit 0
