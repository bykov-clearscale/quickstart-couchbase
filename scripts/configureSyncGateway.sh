#!/usr/bin/env bash

echo "Running configureSyncGateway.sh"

# This is all to figure out what our rally point is.  There might be a much better way to do this.
yum -y install jq

region=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document \
  | jq '.region'  \
  | sed 's/^"\(.*\)"$/\1/' )

rallyInstanceID=$(aws ec2 describe-instances --filters "Name=tag:rally,Values=true" --query  'Reservations[0].Instances[0].InstanceId' --output text)

rallyPublicDNS=$(aws ec2 describe-instances \
    --region ${region} \
    --query  'Reservations[0].Instances[0].NetworkInterfaces[0].PrivateIpAddress' \
    --instance-ids ${rallyInstanceID} \
    --output text)
echo rallyPublicDNS ${rallyPublicDNS}

serverDNS=${rallyPublicDNS}

file="/opt/sync_gateway/etc/sync_gateway.json"
echo '
{
  "interface": "0.0.0.0:4984",
  "adminInterface": "0.0.0.0:4985",
  "log": ["*"],
  "databases": {
    "database": {
      "server": "http://'${serverDNS}':8091",
      "bucket": "sync_gateway",
      "users": {
        "GUEST": { "disabled": false, "admin_channels": ["*"] }
      }
    }
  }
}
' > ${file}
chmod 755 ${file}
chown sync_gateway ${file}
chgrp sync_gateway ${file}

# Need to restart to load the changes
service sync_gateway stop
service sync_gateway start
