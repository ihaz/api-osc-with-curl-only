#!/bin/sh
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# - Redistributions of source code must retain the above copyright notice,
#   this list of conditions and the following disclaimer.
# - Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
# - Neither the name of Arthur Gouros nor the names of its contributors
#   may be used to endorse or promote products derived from this software
#   without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#
#
# Create an OWS v4 signed API request without using CLI or Python boto3
#
# This is based on info from the following link:
# https://docs.outscale.com/api#authentication
#
# OSC AK/SK
source auth.conf

region="eu-west-2"
service="icu"
dateValue1=`TZ=GMT date "+%Y%m%d"`
dateValue2=`TZ=GMT date "+%Y%m%dT%H%M%SZ"`
# Payload is often empty for most GET service requests.
request_payload=""

# Use AWS CLI option 
request_payload=$( printf '{"FromDate": "2021-11-01", "ToDate": "2021-11-05" }' )
# echo "DEBUG: request_payload (${#request_payload}) : ${request_payload}"

#------------------------------------
# Step 1 - Create canonical request.
#------------------------------------
request_payload_sha256=$( printf "${request_payload}" | openssl dgst -binary -sha256 | xxd -p -c 256 )
canonical_request=$( printf "POST
/

content-type:application/x-amz-json-1.0
host:icu.eu-west-2.outscale.com
x-amz-date:${dateValue2}

content-type;host;x-amz-date
${request_payload_sha256}" )

# echo "DEBUG: canonical request: ${canonical_request}"

#------------------------------------
# Step 2 - Create string to sign.
#------------------------------------
canonical_request_sha256=$( printf "${canonical_request}" | openssl dgst -binary -sha256 | xxd -p -c 256 )
stringToSign=$( printf "AWS4-HMAC-SHA256
${dateValue2}
${dateValue1}/${region}/${service}/aws4_request
${canonical_request_sha256}" )
# echo "DEBUG: stringToSign: ${stringToSign}"

#------------------------------------
# Step 3 - Calculate signature.
#------------------------------------
kSecret=$(   printf "AWS4${oscSecret}" | xxd -p -c 256 )
kDate=$(     printf "${dateValue1}"    | openssl dgst -binary -sha256 -mac HMAC -macopt hexkey:${kSecret}       | xxd -p -c 256 )
kRegion=$(   printf "${region}"        | openssl dgst -binary -sha256 -mac HMAC -macopt hexkey:${kDate}         | xxd -p -c 256 )
kService=$(  printf "${service}"       | openssl dgst -binary -sha256 -mac HMAC -macopt hexkey:${kRegion}       | xxd -p -c 256 )
kSigning=$(  printf "aws4_request"     | openssl dgst -binary -sha256 -mac HMAC -macopt hexkey:${kService}      | xxd -p -c 256 )
signature=$( printf "${stringToSign}"  | openssl dgst -binary -hex -sha256 -mac HMAC -macopt hexkey:${kSigning} | sed 's/^.* //' )
# echo "DEBUG: signature: ${signature}"

#------------------------------------
# Step 4 - Add signature to request.
#------------------------------------
#curl --request GET --silent \
#     -H "Authorization: AWS4-HMAC-SHA256 Credential=${oscKey}/${dateValue1}/${region}/ec2/aws4_request, SignedHeaders=content-type;host;x-amz-date, Signature=${signature}" \
#     -H "Content-type: application/x-www-form-urlencoded; charset=utf-8" \
#     -H "Host: icu.eu-west-2.outscale.com" \
#     -H "X-Amz-Date: ${dateValue2}" \
#     "https://icu.eu-west-2.outscale.com?Action=ReadConsumptionAccount&Version=2010-05-08"


curl --request POST --silent \
     -H "Accept: application/json" \
     -H "Authorization: AWS4-HMAC-SHA256 Credential=${oscKey}/${dateValue1}/${region}/${service}/aws4_request, SignedHeaders=content-type;host;x-amz-date, Signature=${signature}" \
     -H "Content-Encoding: amz-1.0" \
     -H "Content-Length: ${#request_payload}" \
     -H "Content-Type: application/x-amz-json-1.0" \
     -H "Connection: keep-alive" \
     -H "Host:icu.eu-west-2.outscale.com" \
     -H "X-Amz-Date: ${dateValue2}" \
     -H "X-Amz-Target: TinaIcuService.ReadConsumptionAccount" \
     -d "${request_payload}" \
     "https://icu.eu-west-2.outscale.com" > conso-eu-west-2.json

cat conso-eu-west-2.json
