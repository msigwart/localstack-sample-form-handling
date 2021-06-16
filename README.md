# Creating a simple form handling service using LocalStack and AWS
In this tutorial, we will create a simple form handling service using AWS Lambda (form handling logic), 
API Gateway (exposing http api), DynamoDB (storing form submissions), and CloudWatch (logging).

## Prerequisites
This tutorial assumes you have the following tools installed

* AWS CLI (TODO Link)
* LocalStack CLI (TODO Link)
* `awslocal` (could this be installed by default when installing LocalStack?)

## Setup
1. Run command `alias aws=awslocal`. 
Now you're running each `aws` command against LocalStack.

2. Start LocalStack
```
localstack start
```

## Create the Lambda function
Create the function that will be responsible for handling form submissions:
```
exports.handler = async (event) => {
  console.log('Received event', event);
  return { "message": "Hello from Lambda!" }
};
```

### Create the Lambda execution role
Our function is going to need certain permissions in order to access other AWS resources.
For now, our function is going to need just the following permissions:

* AWSLambdaBasicExecutionRole – Permission to upload logs to CloudWatch

To create the execution role, run the following command
```
aws iam create-role --role-name lambda-ex --assume-role-policy-document '{"Version": "2012-10-17","Statement": [{ "Effect": "Allow", "Principal": {"Service": "lambda.amazonaws.com"}, "Action": "sts:AssumeRole"}]}'
```

Add the AWSLambdaBasicExecutionRole policy to the execution role
```
aws iam attach-role-policy --role-name lambda-ex --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
```

Retrieve the newly created role
```
aws iam get-role --role-name lambda-ex
```
This will print something like the following:
```
{
    "Role": {
        "Path": "/",
        "RoleName": "lambda-ex",
        "RoleId": "rfvca079j6dostybta66",
        "Arn": "arn:aws:iam::000000000000:role/lambda-ex",
        "CreateDate": "2021-06-15T10:19:32.249000+00:00",
        "AssumeRolePolicyDocument": {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Principal": {
                        "Service": "lambda.amazonaws.com"
                    },
                    "Action": "sts:AssumeRole"
                }
            ]
        },
        "MaxSessionDuration": 3600
    }
}
```
Note the `"Arn"` property. ARN stands for Amazon Resource Name is used to [uniquely identify any AWS resource](https://docs.aws.amazon.com/general/latest/gr/aws-arns-and-namespaces.html). 
We will need this in the next step when we create the Lambda function. 


### Upload the function to AWS Lambda
Create a zip archive containing the function
```
zip function.zip index.js
```
> Important: the index.js file must be in the root of the zip archive

Create the Lambda function setting the `--role` parameter to the ARN 
value of the role we created in the step before.
```
aws lambda create-function --function-name my-function \
--zip-file fileb://function.zip --handler index.handler --runtime nodejs12.x \
--role arn:aws:iam::000000000000:role/lambda-ex
```

Test the Lambda function
```
aws lambda invoke --function-name my-function out --log-type Tail \
--query 'LogResult' --output text |  base64 -d
```
You should see the following output:
```
START RequestId: ea652058-c958-13e0-687c-460d3cf5dbac Version: $LATEST
2021-06-15T10:31:49.263Z        ea652058-c958-13e0-687c-460d3cf5dbac    INFO    Received event {}
END RequestId: ea652058-c958-13e0-687c-460d3cf5dbac
REPORT RequestId: ea652058-c958-13e0-687c-460d3cf5dbac  Init Duration: 132.56 ms        Duration: 10.98 ms      Billed Duration: 11 ms  Memory Size: 1536 MB    Max Memory Used: 41 MB  % 
```

Get the function info:
```
aws lambda get-function --function-name my-function
```

This will produce the following output. This time take note of the function's ARN.
```
{
    "Configuration": {
        "FunctionName": "my-function",
        "FunctionArn": "arn:aws:lambda:us-east-1:000000000000:function:my-function",
        "Runtime": "nodejs12.x",
        "Role": "arn:aws:iam::000000000000:role/lambda-ex",
        "Handler": "index.handler",
        "CodeSize": 279,
        "Description": "",
        "Timeout": 3,
        "LastModified": "2021-06-16T10:49:22.524+0000",
        "CodeSha256": "8S+RX4OEJPmY5fvun4t7G2e1tZ+n9W7jBFDZ+fLL3z4=",
        "Version": "$LATEST",
        "VpcConfig": {},
        "TracingConfig": {
            "Mode": "PassThrough"
        },
        "RevisionId": "9d2c1bc8-3b20-4d5b-8026-86088ebd626f",
        "Layers": [],
        "State": "Active",
        "LastUpdateStatus": "Successful",
        "PackageType": "Zip"
    },
    "Code": {
        "Location": "http://localhost:4566/2015-03-31/functions/my-function/code"
    },
    "Tags": {}
}

```

## Expose function via HTTP
Next we need to expose the function as a public API via HTTP.
For this, we're going to use [Amazon API Gateway](https://docs.aws.amazon.com/apigateway/latest/developerguide/getting-started.html).
Note that we set the `--target` parameter to our Lambda function's ARN. 
```
aws apigatewayv2 create-api \
    --name my-http-api \
    --protocol-type HTTP \
    --target arn:aws:lambda:us-east-1:000000000000:function:my-function
```

You should see something like the following output:
```
{
    "ApiEndpoint": "d0bde0d3.execute-api.localhost.localstack.cloud:4566",
    "ApiId": "d0bde0d3",
    "Name": "my-http-api",
    "ProtocolType": "HTTP"
}
```
Take note of the API ID (`ApiId`) and the API endpoint (`ApiEndpoint`). 
Through the API endpoint we will able to call our function via HTTP.

But first we need to add a permission for the API to invoke the Lambda function. 
Execute the following command replacing {API_ID} with the API ID:
```
aws lambda add-permission \
--function-name arn:aws:lambda:us-east-1:000000000000:function:my-function \
--statement-id api-gateway-invoke \
--action lambda:InvokeFunction \
--principal apigateway.amazonaws.com \
--source-arn "arn:aws:execute-api:us-east-1:000000000000:{API_ID}/*"
```

Now you can test the endpoint:
```
curl http://d0bde0d3.execute-api.localhost.localstack.cloud:4566
```

## Store form submissions in DynamoDB
So far we're not doing much in our form handling logic.
As a next step, we're going to add persistence of form submissions via Amazon DynamoDB.

TODO

## Teardown
Remove Lambda function
TODO

Remove API Gateway
TODO

Remove Log Group
TODO

Remove Execution Role
TODO

