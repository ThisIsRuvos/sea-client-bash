#!/bin/bash
set -e

# Client-specific credentials
read -p 'Client ID: ' client_id
read -s -p $'Client Secret: \n' client_secret
read -p 'Cognito Identity Pool ID: ' cognitoIdentityPoolId

# Environment parameters
keycloakHostname="keycloak.test.steve.naphsis.us"

# Get access token from Keycloak
res=$(curl -X 'POST' \
  'https://'$keycloakHostname'/auth/realms/api-users/protocol/openid-connect/token' \
  -H 'accept: application/json' \
  -sS \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d 'grant_type=client_credentials&client_id='$client_id'&client_secret='$client_secret)
token=$(echo $res | jq -r '.access_token')

# Get an Identity from the Cognito Identity Pool
res=$(curl -X 'POST' \
  'https://cognito-identity.us-east-1.amazonaws.com' \
  -sS \
  -H 'Content-Type: application/x-amz-json-1.1' \
  -H 'X-Amz-Target: com.amazonaws.cognito.identity.model.AWSCognitoIdentityService.GetId' \
  -d '{"IdentityPoolId":"'$cognitoIdentityPoolId'", "Logins": {"'$keycloakHostname'/auth/realms/api-users": "'$token'"}}')
IdentityId=$(echo $res | jq -r '.IdentityId')

# Get AWS credentials
res=$(curl -X 'POST' \
  'https://cognito-identity.us-east-1.amazonaws.com' \
  -sS \
  -H 'Content-Type: application/x-amz-json-1.1' \
  -H 'X-Amz-Target: com.amazonaws.cognito.identity.model.AWSCognitoIdentityService.GetCredentialsForIdentity' \
  -d '{"IdentityId":"'$IdentityId'", "Logins": {"'$keycloakHostname'/auth/realms/api-users": "'$token'"}}')
export AWS_ACCESS_KEY_ID=$(echo $res | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo $res | jq -r '.Credentials.SecretKey')
export AWS_SESSION_TOKEN=$(echo $res | jq -r '.Credentials.SessionToken')

# Then interact with AWS services using those credentials
# In the case of STEVE External API, something like the following...
# Poll the SQS Queue
# Grab S3 Object Keys from SQS messages
# Get Objects from S3 (Equivalent to downloading a file from STEVE)
# Put Objects to S3 (Equivalent to uploading a file to STEVE)

# For the sake of verification, we'll check our identity via STS
aws sts get-caller-identity
