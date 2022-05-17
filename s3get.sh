#!/bin/bash
set -e

# Environment-specific configuration
s3bucket=""

# Client-specific configuration
client_id=""
s3ObjectSuffix=""
s3ObjectKey="${client_id}/inbound/${s3ObjectSuffix}"

region="us-east-1"
host="${s3bucket}.s3.amazonaws.com"
service="s3"
dateValue1=`TZ=GMT date "+%Y%m%d"`
dateValue2=`TZ=GMT date "+%Y%m%dT%H%M%SZ"`

# empty request payload for s3 get object
request_payload=""

# Build a canonical request per AWS specs
request_payload_sha256=$( printf "${request_payload}" | openssl dgst -binary -sha256 | xxd -p -c 256 )
canonical_request=$( printf "GET
/${s3ObjectKey}

host:${host}
x-amz-content-sha256:${request_payload_sha256}
x-amz-date:${dateValue2}
x-amz-security-token:${AWS_SESSION_TOKEN}

host;x-amz-content-sha256;x-amz-date;x-amz-security-token
${request_payload_sha256}" )
#echo "DEBUG: canonical request: ${canonical_request}"

# Build the string to sign
canonical_request_sha256=$( printf "${canonical_request}" | openssl dgst -binary -sha256 | xxd -p -c 256 )
stringToSign=$( printf "AWS4-HMAC-SHA256
${dateValue2}
${dateValue1}/${region}/${service}/aws4_request
${canonical_request_sha256}" )
#echo "DEBUG: stringToSign: ${stringToSign}"

# Signature calculation
kSecret=$(   printf "AWS4${AWS_SECRET_ACCESS_KEY}" | xxd -p -c 256 )
kDate=$(     printf "${dateValue1}"    | openssl dgst -binary -sha256 -mac HMAC -macopt hexkey:${kSecret}       | xxd -p -c 256 )
kRegion=$(   printf "${region}"        | openssl dgst -binary -sha256 -mac HMAC -macopt hexkey:${kDate}         | xxd -p -c 256 )
kService=$(  printf "${service}"       | openssl dgst -binary -sha256 -mac HMAC -macopt hexkey:${kRegion}       | xxd -p -c 256 )
kSigning=$(  printf "aws4_request"     | openssl dgst -binary -sha256 -mac HMAC -macopt hexkey:${kService}      | xxd -p -c 256 )
signature=$( printf "${stringToSign}"  | openssl dgst -binary -hex -sha256 -mac HMAC -macopt hexkey:${kSigning} | sed 's/^.* //' )
#echo "DEBUG: signature: ${signature}"

curl -X GET -sS \
     -H "Authorization: AWS4-HMAC-SHA256 Credential=${AWS_ACCESS_KEY_ID=}/${dateValue1}/${region}/${service}/aws4_request, SignedHeaders=host;x-amz-content-sha256;x-amz-date;x-amz-security-token, Signature=${signature}" \
     -H "host: ${host}" \
     -H "x-amz-content-sha256: ${request_payload_sha256}" \
     -H "x-amz-date: ${dateValue2}" \
     -H "x-amz-security-token: ${AWS_SESSION_TOKEN}" \
     "https://${host}/${s3ObjectKey}"
