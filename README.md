# QiiteneeYo

## What's this?
QiiteneeYo is a project to collect experiences of failure.

After fetching articles from Qiita, this curate articles if the one is about failure experiences or not, stock them to AWS S3 and upload Qiita as a round-up article.

These round-up articles are managed by using AWS dynamoDB, which stores article's id assined by Qiita, post time and expiration limit.

So as to all of these works are done in lambda, there're docker configurations in this repositry.

This script working in our AWS account and generate and post articles. To find them, access https://qiita.com/ and search with "Qiita トラブルシューティング・失敗集".

## What we want to do
Now, QiiteneeYo is a service just collect and curate with simple logic.
We expect, however, this will be able to curate more human-like way using more advanced, for example, bag of words algorithm.

## Setup

### Clone into local

```
git clone https://github.com/MingSiro71/QiiteneeYo.git
```

### Make S3 bucket

- Open S3 in AWS console.
- Make new bucket
- Note bucket name and region

Q. Should I allow public access?
A. No. QiiteneeYo use aws-sdk. If you give sdk credential belonging to role in the same account, you can access in private.

Q. Should I enable bucket versiong?
A. No. In general usage, QiiteneeYo makes datastock with date in object key (or file name).

### Make table in dynanoDB

- Open dynamoDB AWS in console
- Make table named "Postings" with key id(string)

Q. Can I make table in other name?
A. Yes or No. Table name is hard coded, but you can grep and overwrite it.

Q. Should I make index?
A. No. QiiteneeYo uses "scan" of sdk. Which uses no key.

### Make policy and user

- Open Iam in AWS console
- Select policy settings
- Make new policy for access S3 bucket
- Make new policy for access dynamoDB table
- Make new group and attach these policy
- Make new user in the group

Don't forget log in an iam with authority to make new iam

Examples of policy for S3

```json:policy
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "s3:*",
            "Resource": [
                "arn:aws:s3:::qiiteneeyo-datastock",
                "arn:aws:s3:::qiiteneeyo-datastock/*"
            ]
        }
    ]
}
```

Examples of policy for dynamoDB

```json:policy
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "ListAndDescribe",
            "Effect": "Allow",
            "Action": [
                "dynamodb:List*",
                "dynamodb:DescribeReservedCapacity*",
                "dynamodb:DescribeLimits",
                "dynamodb:DescribeTimeToLive"
            ],
            "Resource": "*"
        },
        {
            "Sid": "SpecificTable",
            "Effect": "Allow",
            "Action": [
                "dynamodb:BatchGet*",
                "dynamodb:DescribeStream",
                "dynamodb:DescribeTable",
                "dynamodb:Get*",
                "dynamodb:Query",
                "dynamodb:Scan",
                "dynamodb:BatchWrite*",
                "dynamodb:CreateTable",
                "dynamodb:Delete*",
                "dynamodb:Update*",
                "dynamodb:PutItem"
            ],
            "Resource": "arn:aws:dynamodb:::table/Posting"
        }
    ]
}
```

### Generate and set access key

- Open Iam in AWS console
- Select user made for QiiteneeYo
- Select "security credentials" tab
- Click access key generate button
- Note access key and secret key
- Make "./module/qiiteneeyo/.env" and set them

To set into .env, See
https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-envvars.html#envvars-list


### Generate and set access key

- Open Elastic Container Registry(ECR) in AWS console
- Make repositry to upload container
- Note repositry's resource name

Resource name is like:
```
999999999999.dkr.ecr.ap-northeast-1.amazonaws.com/<reponame>
```

### Build and upload container image
In local repositry

```
docker build . -t <resource name>

```

### Tag and upload container
In local repositry

```
# Login AWS from repositry to connect ECR
aws ecr get-login-password --region region | docker login --username AWS --password-stdin aws_account_id.dkr.ecr.region.amazonaws.com

docker push <resource name>
```

### Deploy on lambda

- Open Lambda in AWS console
- Make new function
- Select container image
- Name something nice
- Reffer latest image from ECR repositry 
- Confirm
- Select function
- Click to open image configure
- Overwrite Entrypoint to /var/task/bootstrap
- Overwrite CMD to lambda_function.lambda_handler
- Overwrite WORKDIR to /var/task
- Select configure and click 'edit'
- Increase memory to 256
- Increase timeout limit to 5 minutes
- Test function with hello

The test is expected to be well done.
You can see log Clowd Watch.

### Schedule autorun

- Open EventBridge in AWS console
- Select rule
- Make new rule
- Select "schedule" as the pattern and set it
- Select target to "lambda function"
- Select your function
- Confirm

Sample for cron schedule
The cron syntax in AWS is differnt from that in Unix.
```cron
55 23 ? * FRI *
```
Note that time in EventBridge is UTC regardless of region you set the event in.
So in the case of above, event runs

- 8:55 in JST
- Every friday

