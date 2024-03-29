#!/bin/sh
#
# BSD License for ReadAccessKeys-logmdp-oApi.sh
# Copyright (c) 2021, Hazout Ilane
# All rights reserved.
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
# Create an OSC v4 signed API with Basic Authentification Login / mdp
#
# This is based on info from the following link:
# https://docs.aws.amazon.com/general/latest/gr/sigv4_signing.html
#
# Author: Ilane Hazout - 29/01/2022

# OSC login/mdb
source auth-user.conf

token_for_basic_auth=$(echo -n "$oscKey:$oscSecret" | base64)

region="eu-west-2"
service="api"
dateValue=`TZ=GMT date "+%Y%m%d"`
dateValueIso=`TZ=GMT date "+%Y%m%dT%H%M%SZ"`
# Use AWS CLI option --generate-cli-skeleton to get the --cli-input-json request_payload.
request_payload=$( printf "{}" )
# echo "DEBUG: request_payload (${#request_payload}) : ${request_payload}"

#------------------------------------
# Step 1 - Create canonical request.
#------------------------------------
request_payload_sha256=$( printf "${request_payload}" | openssl dgst -binary -sha256 | xxd -p -c 256 )

canonical_request=$( printf "POST
/api/latest/ReadAccessKeys

content-type:application/json; charset=utf-8
host:api.eu-west-2.outscale.com
x-osc-date:${dateValueIso}

content-type;host;x-osc-date
${request_payload_sha256}")
#echo "DEBUG: canonical request: ${canonical_request}"

#------------------------------------
# Step 2 - Create string to sign.
#------------------------------------
canonical_request_sha256=$( printf "${canonical_request}" | openssl dgst -binary -sha256 | xxd -p -c 256 )
#echo ">canonical_request_sha256 : ${canonical_request_sha256}"
ALGO="OSC4-HMAC-SHA256"
stringToSign=$( printf "${ALGO}
${dateValueIso}
${dateValue}/${region}/api/osc4_request
${canonical_request_sha256}" )
# echo "DEBUG: stringToSign: ${stringToSign}"

#------------------------------------
# Step 3 - Calculate signature.
#------------------------------------
kSecret=$(   printf "OSC4${oscSecret}" | xxd -p -c 256 )
kDate=$(     printf "${dateValue}"    | openssl dgst -binary -sha256 -mac HMAC -macopt hexkey:${kSecret}       | xxd -p -c 256 )
kRegion=$(   printf "${region}"        | openssl dgst -binary -sha256 -mac HMAC -macopt hexkey:${kDate}         | xxd -p -c 256 )
kService=$(  printf "${service}"       | openssl dgst -binary -sha256 -mac HMAC -macopt hexkey:${kRegion}       | xxd -p -c 256 )
kSigning=$(  printf "osc4_request"     | openssl dgst -binary -sha256 -mac HMAC -macopt hexkey:${kService}      | xxd -p -c 256 )
signature=$( printf "${stringToSign}"  | openssl dgst -binary -hex -sha256 -mac HMAC -macopt hexkey:${kSigning} | sed 's/^.* //' )
# echo "DEBUG: signature: ${signature}"

#------------------------------------
# Step 4 - Add signature to request.
#------------------------------------
#echo ">> ${#request_payload}"
curl --request POST --silent \
     -H "Host: api.eu-west-2.outscale.com" \
     -H "Accept-Encoding: gzip, deflate" \
     -H "Accept: */*" \
     -H "Content-Type: application/json; charset=utf-8" \
     -H "Connection: keep-alive" \
     -H "User-Agent: 'oAPI CLI 666" \
     -H "X-Osc-Date: ${dateValueIso}" \
     -H "Authorization: Basic ${token_for_basic_auth}" \
     -H "Content-Length: ${#request_payload}" \
     -d "${request_payload}" \
     "https://api.eu-west-2.outscale.com/api/latest/ReadAccessKeys" > readak.data.json

cat readak.data.json | jq .AccessKeys[] | jq -s | jtbl

exit $?
~
