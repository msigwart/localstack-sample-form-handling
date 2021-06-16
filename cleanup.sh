#!/bin/sh
if [[ $# -eq 0 ]] ; then
    echo 'First argument should be either aws or awslocal'
    exit 1
fi
command -v $1
temp=$($1 sts get-caller-identity --output json --query "Account")
temp="${temp%\"}" &&
account="${temp#\"}" &&
echo "Account: $account"

echo "Deleting API Gateway"
$1 lambda remove-permission \
--function-name my-function \
--statement-id api-gateway-invoke &&

temp=$($1 apigatewayv2 get-apis --output json --query "Items[?Name=='my-http-api'].ApiId | [0]")
temp="${temp%\"}" &&
apiId="${temp#\"}" &&
$1 apigatewayv2 delete-api --api-id "$apiId"

echo "Deleting function"
$1 lambda delete-function --function-name my-function

echo "Deleting execution role"
$1 iam detach-role-policy --role-name lambda-ex --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole &&
$1 iam delete-role --role-name lambda-ex

echo "Teardown done."
