!# /bin/bash

user="" #"devadmin"
password="" #"*******"
org="Webjet_Marketing_Pty_Ltd_42809_SVC"
vcloud_url="https://vcloud.macquarieview.com/api/sessions"
vcloud_session_url="https://vcloud.macquarieview.com/api/session"
vcloud_org_url="https://vcloud.macquarieview.com/api/org"
log="vcloud_session.log"

#log_in
#curl -i -k -H "Accept:application/*+xml;version=1.5" -u 'devadmin@Webjet_Marketing_Pty_Ltd_42809_SVC:P@ssw0rd' -X POST https://vcloud.macquarieview.com/api/sessions
curl -i -k -H "Accept:application/*+xml;version=1.5" -u "$user@$org:$password" -X POST "$vcloud_url" | sed 's/
//g' > $log 

#log_out
vcloud_session_auth=$(grep "x-vcloud-authorization" $log)
#curl -i -k -H "Accept:application/*+xml;version=1.5" -H "$vcloud_session_auth" -X DELETE "$vcloud_session_url" >> $log

#check_org_access
curl -i -k -H "Accept:application/*+xml;version=1.5" -H "$vcloud_session_auth" -X GET "$vcloud_org_url" | sed 's/
//g' >> $log

curl -i -k -H "Accept:application/*+xml;version=1.5" -H "$vcloud_session_auth" -X GET "https://vcloud.macquarieview.com/api/org/48014a2f-0331-4a60-966a-335608539470"
