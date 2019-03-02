#!/usr/bin/env bash

#SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )" # no support for symlinks
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")" # supports symlinks

E_ABORT_CHOSEN=2


# AWS SAM in Docker
aws_sam ()
{
    local tty=
    tty -s && tty=--tty

    docker run \
        ${tty} \
        --interactive \
        --rm \
        --volume /home/$(whoami)/.aws:/home/samcli/.aws \
        --entrypoint sam \
        pahud/aws-sam-cli:latest "$@"
}


# AWS CLI in Docker
aws_cli ()
{
    local tty=
    tty -s && tty=--tty

    local accessKeyId=
    [[ ! -z ${AWS_ACCESS_KEY_ID} ]] && accessKeyId="--env \"AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}\""

    local secretAccessKey=
    [[ ! -z ${AWS_SECRET_ACCESS_KEY} ]] && secretAccessKey="--env \"AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}\""

    local defaultRegion=
    [[ ! -z ${AWS_DEFAULT_REGION} ]] && defaultRegion="--env \"AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}\""

    docker run \
        ${tty} \
        --interactive \
        --rm \
        --user $(id -u):$(id -g) \
        --volume "$(pwd):/project" \
        --volume /home/$(whoami)/.aws:/.aws \
        ${accessKeyId} \
        ${secretAccessKey} \
        ${defaultRegion} \
        mesosphere/aws-cli "$@"
}


_check_for_credentials ()
{
    local state_1=
    local state_2=

    if [[ -z ${AWS_ACCESS_KEY_ID} ]]; then
        aws_cli configure get aws_access_key_id
        state_1=$?
    else
        echo ${AWS_ACCESS_KEY_ID}
    fi

    if [[ -z ${AWS_SECRET_ACCESS_KEY} ]]; then
        aws_cli configure get aws_secret_access_key
        state_2=$?
    else
        echo ${AWS_SECRET_ACCESS_KEY}
    fi

    if [[ ${state_1} -ne 0 || ${state_1} -ne 0 ]]; then
        echo 'AWS credentials not found.'
        echo 'Please follow the instructions at https://bref.sh/docs/installation.html'

        return 1
    fi
}


_check_for_template_files ()
{
    if [[ -f "${PWD}/template.yaml" || -f "${PWD}/index.php" ]]; then
        echo "The directory '${PWD}' already contains a 'template.yaml' and/or 'index.php' file."

        return 1
    fi
}


_make_choice ()
{
    local outputVariableName="$1"
    shift
    local options=("$@")
    quitOption=$(( ${#options[@]}+1 ))
    PS3="Your selection: "

    select opt in "${options[@]}" "-= Abort =-"; do
        if [[ $REPLY -ge 1 && $REPLY -lt ${quitOption} ]]; then
            let "${outputVariableName} = ${REPLY}"
            break
        elif [[ $REPLY -eq ${quitOption} ]]; then
            return ${E_ABORT_CHOSEN}
        else
            echo "Invalid option, try again or press [${quitOption}] to quit."
            echo
            continue
        fi
    done
}



#####################################

lambdaTypes=(
    'PHP function'
    'HTTP application'
    'Console application'
)
templateDirectories=(
    'default'
    'http'
    'console'
)

echo "Checking for AWS credentials ..."
_check_for_credentials || exit $?

echo
echo "Checking for present template files ..."
_check_for_template_files || exit $?
echo "Current directory clear, proceding ..."

echo
echo "What kind of lambda do you want to create?"
echo "(You will be able to add more functions later by editing 'template.yaml'.)"
selectedLambdaType=
_make_choice 'selectedLambdaType' "${lambdaTypes[@]}"
[[ $? -eq ${E_ABORT_CHOSEN} ]] && exit 0

selectedTemplateDirectory=${templateDirectories[selectedLambdaType-1]}
rootPath="${SCRIPT_DIR}/template/${selectedTemplateDirectory}"

echo
echo "Copying files ..."
cp --verbose --recursive "${rootPath}/." "${PWD}"

echo
echo 'Project initialized and ready to test or deploy.'

exit 0
