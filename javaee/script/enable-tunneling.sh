#!/bin/bash

# Enable admin server tunneling
curl -v \
--user #wlsUserName#:#wlsPassword# \
-H X-Requested-By:MyClient \
-H Accept:application/json \
-H Content-Type:application/json \
-d "{
  tunnelingEnabled:true
}" \
-X POST #adminVMDNS#:7001/management/weblogic/latest/edit/servers/admin
exit 0
