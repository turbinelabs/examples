#!/bin/bash

usage () {
    echo "deploy.sh <stage> <template file>"
}


if [ -z $1 ]
then
    echo "error: stage unset"
    usage
    exit 1
else
    export TBN_STAGE=$1
fi

if [ ! -f "$2" ]
then
    echo "error: $1/deploy-template.yaml not found"
    usage
    exit 1
else
    export TEMPLATE_FILE=$2
fi

export DEPLOY_DATE=`date -u +%FT%T%z`

if [ -z "$CIRCLE_SHA1" ]
then
    export GIT_SHA=`git rev-parse HEAD`
    echo "CIRCLE_SHA1 unset, setting GIT_SHA to $GIT_SHA"
fi

if [ $TBN_STAGE = "dev" ]
then
    export TBN_VERSION=$CIRCLE_BRANCH
    export GIT_BRANCH=$CIRCLE_BRANCH
    echo "Circle branch set to $CIRCLE_BRANCH, executing $TBN_STAGE deploy of version $TBN_VERSION"
elif [ $TBN_STAGE = "prod" ]
then
    export TBN_VERSION=$CIRCLE_TAG
    export GIT_TAG=$CIRCLE_TAG
    echo "Circle branch tag set to $CIRCLE_TAG, executing $TBN_STAGE deploy of version $TBN_VERSION"
fi

REPLACEMENT_VARS=(GCLOUD_PROJECT_ID GIT_TAG GIT_SHA GIT_BRANCH DEPLOY_DATE TBN_STAGE TBN_VERSION)
REPLACEMENT_SED=""
for v in ${REPLACEMENT_VARS[@]}; do
    eval rvar=\$$v
    REPLACEMENT_SED+="s~\\\$$v~$rvar~; "
done
echo "REPLACEMENT_SED: $REPLACEMENT_SED"

DEPLOYMENT_NAME=all-in-one-server-$TBN_STAGE-$TBN_VERSION

echo "DEPLOY SPEC IS:"
cat $TEMPLATE_FILE | sed "$REPLACEMENT_SED"

echo "checking for existing deployment"
kubectl get deployment $DEPLOYMENT_NAME
if [ $? -eq 0 ]
then
    echo "editing existing deployment"
    cat $TEMPLATE_FILE | sed "$REPLACEMENT_SED" | kubectl replace -f -
else
    echo "creating new deployment"
    cat $TEMPLATE_FILE | sed "$REPLACEMENT_SED" | kubectl create -f -
fi
