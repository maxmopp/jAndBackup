#!/system/xbin/ash
#
# 20190205 /jps - restore jAndBackups
# 20191005 /jps - 
# 20201228 A11 has new random subdir, restoring to tmp + pm install, new PUid
#

PATH=/system/xbin:$PATH
alias find=/system/bin/find
alias tar=/system/xbin/tar

BackDir="/sdcard/jAndBackup"

TempDir=/data/local/tmp
User=0

# install the apks first
for AppTar in $(find $BackDir -type f -iname "*-apk.tgz"); do
  Package=$(echo $AppTar | sed -n 's/.*\/\(.*\)-apk.*.tgz/\1/p')
  if  [ "$Package" == "" ]; then
    echo "Error- unerwartetes Format $AppTar"
  else
    echo "Restoring $Package"
    tar -xzf $AppTar  -C $TempDir
    # find errors when restored to /data/data - macht aber nix bis dato
    # user 10 has to be installed manually
    pm install --user $User -r $TempDir/base.apk
  fi
done

# restore system data
for AppTar in $(find $BackDir -type f -iname "*-System.tgz"); do
  Package=$(echo $AppTar | sed -n 's/.*\/\(.*\)-System.tgz/\1/p')
  if  [ "$Package" == "" ]; then             
    echo "Error- unerwartetes Format $AppTar"
  else                       
    echo "Restoring $Package data for System"
    tar -xzf $AppTar -C /                                    
    PUid=$(cmd package list packages -U $Package | awk -v User=${User} -F: '{ print $3 }')
#    # Uid is hex at beginning !?
#    PUid=$(cmd package list packages -U $Package | awk -v User=${User} -F: '{ print "u"User"_"$3 }' \
#         | sed 's/_10/_a/g' | sed 's/_11/_b/g' | sed 's/_12/_c/g' | sed 's/_13/_d/g' \
#         | sed 's/_14/_e/g' | sed 's/_15/_f/g')
    chown -R $PUid:$PUid /data/data/*$Package*
  fi
done

# restore user data, only for User0 here
for AppTar in $(find $BackDir -type f -iname "*-User*.tgz"); do
  Package=$(echo $AppTar | sed -n 's/.*\/\(.*\)-User.*.tgz/\1/p')
  if  [ "$Package" == "" ]; then             
    echo "Error- unerwartetes Format $AppTar"
  else                       
    User=$(echo $AppTar | sed -n 's/.*-User\(.*\)\.tgz/\1/p')             
#    if [ $Package = "net.typeblog.shelter" ] && [ $User != 0 ]; then                                                                                                                                                               
    if [ $User != 0 ]; then                                                                                                                                                               
      echo "FIXME - Will not restore data for $Package for $User - please use jAndRestoreSingle"
    else
      echo "Restoring $Package data for User $User"
      tar -xzf $AppTar -C /                                    
      PUid=$(cmd package list packages -U $Package | awk -v User=${User} -F: '{ print $3 }')
 #     # Uid is hex at beginning !?
 #     PUid=$(cmd package list packages -U $Package | awk -v User=${User} -F: '{ print "u"User"_"$3 }' \
 #        | sed 's/_10/_a/g' | sed 's/_11/_b/g' | sed 's/_12/_c/g' | sed 's/_13/_d/g' \
 #        | sed 's/_14/_e/g' | sed 's/_15/_f/g')
      if [ "$Package" != "misc" ]; then
          chown -R $PUid:$PUid /data/user*/$User/*$Package*
      fi
    fi
  fi
done

echo "Restore databases"
Owner=$(stat -c "%U:%G" /data/data/com.android.providers.userdictionary)
if [ ! -e /data/data/com.android.providers.userdictionary/databases/ ]; then 
  mkdir -p /data/data/com.android.providers.userdictionary/databases/
  chmod 775 /data/data/com.android.providers.userdictionary/databases
  chown $Owner /data/data/com.android.providers.userdictionary/databases
fi
if [ ! -e /data/data/com.android.providers.userdictionary/databases/user_dict.db ]; then
  touch /data/data/com.android.providers.userdictionary/databases/user_dict.db
  chown $Owner /data/data/com.android.providers.userdictionary/databases/user_dict.db
fi
sqlite3  /data/data/com.android.providers.userdictionary/databases/user_dict.db < \
   /data/local/tmp/userdictionary.dmp

