#!/bin/bash
# start-up-names.sh
# http://blog.domenech.org

logger start-up-name.sh Started

#More environment variables than we need but... we always do that
export AWS_CREDENTIAL_FILE=/opt/aws/apitools/mon/credential-file-path.template
export AWS_CLOUDWATCH_HOME=/opt/aws/apitools/mon
export AWS_IAM_HOME=/opt/aws/apitools/iam
export AWS_PATH=/opt/aws
export AWS_AUTO_SCALING_HOME=/opt/aws/apitools/as
export AWS_ELB_HOME=/opt/aws/apitools/elb
export AWS_RDS_HOME=/opt/aws/apitools/rds
export EC2_AMITOOL_HOME=/opt/aws/amitools/ec2
export EC2_HOME=/opt/aws/apitools/ec2
export JAVA_HOME=/usr/lib/jvm/jre
export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/opt/aws/bin:/root/bin

# *** Configure these values with your settings ***
#API Credentials
AWSSECRETS=""
KEYNAME=""
#Hosted Zone ID obtained from Route53 Console once the zone is created
HOSTEDZONEID=""
#Domain name configured in Route53 and used to store our server names
DOMAIN=""
REGION="eu-west-1"
# *** Configuration ends here ***

#Let's get the Credentials that EC2 API needs from .aws-secrets dnscurl.pl file
ACCESSKEY=`cat $AWSSECRETS | grep id | cut -d\' -f2`
SECRETKEY=`cat $AWSSECRETS | grep key | cut -d\' -f2`

#InstanceID Obtained from MetaData 
INSTANCEID=`wget -q -O - http://169.254.169.254/latest/meta-data/instance-id`

#Public Instance IP obtained from MetaData
PUBLICIP=`wget -q -O - http://169.254.169.254/latest/meta-data/public-ipv4`

#IP Currently configured in the DNS server (if exists)
CURRENTDNSIP=`dig $INSTANCEID"."$DOMAIN A | grep -v ^\; | sort | tail -1 | awk '{print $5}'`

#Instance Name obtained from the Instance Custom Tag NAME
WGET="`wget -q -O - http://169.254.169.254/latest/meta-data/instance-id`"
INSTANCENAME=`ec2-describe-instances -O $ACCESSKEY -W $SECRETKEY $WGET -region $REGION --show-empty-fields | grep TAG | grep Name | awk '{ print $5 }'`

echo $INSTANCEID $PUBLICIP $CURRENTDNSIP $INSTANCENAME
logger $INSTANCEID $PUBLICIP $CURRENTDNSIP $INSTANCENAME

#Set the new Hostname using the Instance Tag OR the Instance ID
if [ -n "$INSTANCENAME" ]; then
hostname $INSTANCENAME
logger Hostname from InstanceName set to $INSTANCENAME
else
hostname $INSTANCEID
logger Hostname from InstanceID set to $INSTANCEID
fi

#dnscurl.pl Delete Current InstanceID Public IP A Record to allow Later Update
#COMMAND="<?xml version=\"1.0\" encoding=\"UTF-8\"?><ChangeResourceRecordSetsRequest xmlns=\"https://route53.amazonaws.com/doc/2012-02-29/\"><ChangeBatch><Changes><Change><Action>"DELETE"</Action><ResourceRecordSet><Name>"$INSTANCEID"."$DOMAIN".</Name><Type>A</Type><TTL>60</TTL><ResourceRecords><ResourceRecord><Value>"$CURRENTDNSIP"</Value></ResourceRecord></ResourceRecords></ResourceRecordSet></Change></Changes></ChangeBatch></ChangeResourceRecordSetsRequest>"

#/root/bin/dnscurl.pl --keyfile $AWSSECRETS --keyname $KEYNAME -- -v -H "Content-Type: text/xml; charset=UTF-8" -X POST https://route53.amazonaws.com/2012-02-29/hostedzone/$HOSTEDZONEID/rrset -d "$COMMAND"

#dnscurl.pl Create InstanceID Public IP A Record
#COMMAND="<?xml version=\"1.0\" encoding=\"UTF-8\"?><ChangeResourceRecordSetsRequest xmlns=\"https://route53.amazonaws.com/doc/2012-02-29/\"><ChangeBatch><Changes><Change><Action>"CREATE"</Action><ResourceRecordSet><Name>"$INSTANCEID"."$DOMAIN".</Name><Type>A</Type><TTL>60</TTL><ResourceRecords><ResourceRecord><Value>"$PUBLICIP"</Value></ResourceRecord></ResourceRecords></ResourceRecordSet></Change></Changes></ChangeBatch></ChangeResourceRecordSetsRequest>"

#/root/bin/dnscurl.pl --keyfile $AWSSECRETS --keyname $KEYNAME -- -v -H "Content-Type: text/xml; charset=UTF-8" -X POST https://route53.amazonaws.com/2012-02-29/hostedzone/$HOSTEDZONEID/rrset -d "$COMMAND"

#logger Entry $INSTANCEID.$DOMAIN sent to Route53

#Create DNS A record for Instance Name (if exists)
if [ -n "$INSTANCENAME" ]; then

#dnscurl.pl Delete Current Instance Name Public IP A Record to allow Later Update
COMMAND="<?xml version=\"1.0\" encoding=\"UTF-8\"?><ChangeResourceRecordSetsRequest xmlns=\"https://route53.amazonaws.com/doc/2012-02-29/\"><ChangeBatch><Changes><Change><Action>"DELETE"</Action><ResourceRecordSet><Name>"$INSTANCENAME"."$DOMAIN".</Name><Type>A</Type><TTL>60</TTL><ResourceRecords><ResourceRecord><Value>"$CURRENTDNSIP"</Value></ResourceRecord></ResourceRecords></ResourceRecordSet></Change></Changes></ChangeBatch></ChangeResourceRecordSetsRequest>"

/root/bin/dnscurl.pl --keyfile $AWSSECRETS --keyname $KEYNAME -- -v -H "Content-Type: text/xml; charset=UTF-8" -X POST https://route53.amazonaws.com/2012-02-29/hostedzone/$HOSTEDZONEID/rrset -d "$COMMAND"

#dnscurl.pl Create Instance Name Public IP A Record
COMMAND="<?xml version=\"1.0\" encoding=\"UTF-8\"?><ChangeResourceRecordSetsRequest xmlns=\"https://route53.amazonaws.com/doc/2012-02-29/\"><ChangeBatch><Changes><Change><Action>"CREATE"</Action><ResourceRecordSet><Name>"$INSTANCENAME"."$DOMAIN".</Name><Type>A</Type><TTL>60</TTL><ResourceRecords><ResourceRecord><Value>"$PUBLICIP"</Value></ResourceRecord></ResourceRecords></ResourceRecordSet></Change></Changes></ChangeBatch></ChangeResourceRecordSetsRequest>"

/root/bin/dnscurl.pl --keyfile $AWSSECRETS --keyname $KEYNAME -- -v -H "Content-Type: text/xml; charset=UTF-8" -X POST https://route53.amazonaws.com/2012-02-29/hostedzone/$HOSTEDZONEID/rrset -d "$COMMAND"

logger Entry $INSTANCENAME.$DOMAIN sent to Route53
fi

logger start-up-names.sh Ended
