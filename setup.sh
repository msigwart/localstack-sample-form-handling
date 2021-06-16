#!/bin/bash
if [[ $# -eq 0 ]] ; then
    echo "First argument should be either 'aws' or 'awslocal'"
    exit 1
fi
command -v $1

temp=$($1 sts get-caller-identity --output json --query "Account")
temp="${temp%\"}" &&
account="${temp#\"}" &&
echo "Account: $account"

echo "Creating execution role"
temp=$($1 iam create-role \
    --role-name lambda-ex \
    --assume-role-policy-document '{"Version": "2012-10-17","Statement": [{ "Effect": "Allow", "Principal": {"Service": "lambda.amazonaws.com"}, "Action": "sts:AssumeRole"}]}' \
    --output json \
    --query 'Role.Arn') &&
$1 iam attach-role-policy \
    --role-name lambda-ex \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole &&

temp="${temp%\"}" &&
roleArn="${temp#\"}" &&

sleep 8 &&

echo "Creating function" &&
rm function.zip 2> /dev/null || true &&
zip function.zip index.js &&
temp=$($1 lambda create-function --function-name my-function \
  --zip-file fileb://function.zip --handler index.handler --runtime nodejs12.x \
  --role "$roleArn" \
  --output json \
  --query 'FunctionArn') &&
rm function.zip &&

temp="${temp%\"}" &&
functionArn="${temp#\"}" &&

echo "Creating API" &&
temp=$($1 apigatewayv2 create-api \
    --name my-http-api \
    --protocol-type HTTP \
    --target "$functionArn" \
    --output json \
    --query 'ApiId') &&

temp="${temp%\"}" &&
apiId="${temp#\"}" &&

$1 lambda add-permission \
  --function-name my-function \
  --statement-id api-gateway-invoke \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:us-east-1:$account:$apiId/*" > /dev/null &&

temp=$($1 apigatewayv2 get-api \
    --api-id "$apiId" \
    --output json \
    --query 'ApiEndpoint') &&

temp="${temp%\"}" &&
apiEndpoint="${temp#\"}" &&

echo "API endpoint: $apiEndpoint" &&
echo "Deployment successful."
