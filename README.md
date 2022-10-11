# api-osc-with-curl-only

# Create an OSC v4 signed API request without using CLI or Python boto3

# Get AK with oApi one line 
```curl -XPOST -H "X-Osc-Date: `TZ=GMT date "+%Y%m%dT%H%M%SZ"`" -H "Authorization: Basic `echo -n "user:mdp" | base64`" https://api.eu-west-2.outscale.com/api/v1/ReadAccessKeys```

# Get AK/SK with curl > 7.75 
```curl -s -X POST https://icu.eu-west-2.outscale.com -H 'x-amz-target: TinaIcuService.ListAccessKeys' --user "$OSC_ACCESS_KEY:$OSC_SECRET_KEY" --aws-sigv4 'aws:amz' -H 'Content-Type: application/json' -d '{"AuthenticationMethod": "accesskey"}' | jq .```
