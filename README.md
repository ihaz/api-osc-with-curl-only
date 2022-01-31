# api-osc-with-curl-only

# Create an OSC v4 signed API request without using CLI or Python boto3

# Get AK with one line 
curl -XPOST -H "X-Osc-Date: `TZ=GMT date "+%Y%m%dT%H%M%SZ"`" -H "Authorization: Basic `echo -n "user:mdp" | base64`" https://api.eu-west-2.outscale.com/api/v1/ReadAccessKeys
