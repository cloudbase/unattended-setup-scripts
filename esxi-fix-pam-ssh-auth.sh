#!/bin/sh

/bin/grep '^#PAMFix' /etc/rc.local.d/local.sh > /dev/null 2>&1

if [ $? != 0 ]
then
    /bin/sed -i '/exit 0/d' /etc/rc.local.d/local.sh
    cat <<EOF >> /etc/rc.local.d/local.sh

for i in \$(/bin/grep "/bin/sh" /etc/passwd | cut -f1 -d":")
do
    /bin/sed -i 's/^-:'\$i':/+:'\$i':/g' /etc/security/access.conf
done

/bin/grep local.sh /var/spool/cron/crontabs/root > /dev/null 2>&1
if [ \$? != 0 ]
then
    echo '*    *    *   *   *   /etc/rc.local.d/local.sh' >> /var/spool/cron/crontabs/root
fi
#PAMFix
EOF
fi

/etc/rc.local.d/local.sh
/sbin/auto-backup.sh
