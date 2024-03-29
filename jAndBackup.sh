#!/system/bin/sh
#
# 201900215
# 20190220
#	backup misc per User
#	add incremental, only one copy
# 20191005 error $iUser instead of ${UserID[iUser]}
# 20201228 A11 has new random subdir - only backing up base.apk
#
# needs files jAndBackupPackage.Ignore and jAndBackup.Exclude
# tar  from busybox (usually /system/xbin/tar)
# find from toybox (usually /system/bin/find)
#
#   $1 - SaveSet
#     F Full backup 
#     I Invremental based on differenz ctime of last backup and mtime of data files

# accounts, bluetooth, wifi access points
# was fehlt: data usage policy, wallpaper

PATH=/system/xbin:$PATH
alias find=/system/bin/find
alias tar=/system/xbin/tar

export LD_LIBRARY_PATH=/vendor/lib*:/system/lib*:/data/jpchil/lib
export HOME=/data/jpchil/

Debug=1

SaveSet=$1

if [ "$SaveSet" != "F" ] && [ "$SaveSet" != "I" ]; then echo "Parameter Full or incremental: [F|I]" && exit; fi


BackupDir=/sdcard/jAndBackup
if [ ! -d $BackupDir ]; then mkdir $BackupDir; fi
LogFile=/data/jpchil/log/jAndBackup.log 
echo "`date +%Y%m%d-%H%M` - batchBackup started" > $LogFile

# get UserIDs
UserID=($(pm list users | sed -n 's/.*{\([^:]*\):.*/\1/p'))
let UserCount=${#UserID[*]}-1

# 

for iUser in `seq 0 $UserCount`; do
   echo "\n\nBacking up packages for User ${UserID[iUser]}\n"
   for Package in $(cmd package list packages --user  ${UserID[iUser]}); do
     jPackage=${Package/package:/} 
     echo $jPackage | tee -a  $LogFile
     if [[ $(grep $jPackage /data/jpchil/jAndBackup/jAndBackupPackage.Ignore) ]]; then
       echo "- Skipping package $jPackage" | tee -a $LogFile
     else
       ####### apk
       if [ ! -f $BackupDir/$jPackage-apk.tgz ]; then touch -t 197101010101 $BackupDir/$jPackage-apk.tgz; fi
       let TimeDiff=`date '+%s'`-`stat -c %Y $BackupDir/$jPackage-apk.tgz`
       Result=$(find /data/app/*/*$jPackage*/ -type f -mtime -${TimeDiff}s -name base.apk)
       AppDir=$(echo $Result | sed 's/\/base.apk//') 
       if [ "$Result" != "" ] || [ "$SaveSet" == "F" ]; then
         if [ $Debug -eq 1 ]; then echo "============ Backing up apk for $jPackage"; fi
         tar -X /data/jpchil/jAndBackup/jAndBackup.Exclude -czf $BackupDir/$jPackage-apk.tgz \
                -C $AppDir base.apk 2>>$LogFile
       fi
       ####### system data
      if [ ! -f $BackupDir/$jPackage-System.tgg ]; then touch -t 197101010101 $BackupDir/$jPackage-System.tgg; fi
       let TimeDiff=`date '+%s'`-`stat -c %Y $BackupDir/$jPackage-System.tgg`
       Result=$(find /data/data/*$jPackage*/ -type f -mtime -${TimeDiff}s | grep -E -iv 'cache|thumbnail')
       if [ "$Result" != "" ] || [ "$SaveSet" == "F" ]; then
         if [ $Debug -eq 1 ]; then echo "============ Backing up system data  for $jPackage"; fi
         tar -X /data/jpchil/jAndBackup/jAndBackup.Exclude -czf - \
                /data/data/*$jPackage*/ 2>>$LogFile | \
                /system/xbin/gpg --batch --yes --encrypt --recipient joerg@jpchil.at -o $BackupDir/$jPackage-System.tgg
       fi
       ####### user data
       if [ ! -f $BackupDir/$jPackage-User${UserID[iUser]}.tgg ]; then touch -t 197101010101 $BackupDir/$jPackage-User${UserID[iUser]}.tgg; fi
       let TimeDiff=`date '+%s'`-`stat -c %Y $BackupDir/$jPackage-User${UserID[iUser]}.tgg`
       Result=$(find /data/user/${UserID[iUser]}/*$jPackage*/ /data/user_de/${UserID[iUser]}/*$jPackage*/ -type f -mtime -${TimeDiff}s | grep -E -iv 'cache|thumbnail')
       if [ "$Result" != "" ] || [ "$SaveSet" == "F" ]; then
         if [ $Debug -eq 1 ]; then echo "============ Backing up Data User${UserID[iUser]} for $jPackage"; fi
         tar -X /data/jpchil/jAndBackup/jAndBackup.Exclude -czf - \
              /data/user/${UserID[iUser]}/*$jPackage*/ /data/user_de/${UserID[iUser]}/*$jPackage*/ 2>>$LogFile | \
              /system/xbin/gpg --batch --yes --encrypt --recipient joerg@jpchil.at -o $BackupDir/$jPackage-User${UserID[iUser]}.tgg
       fi
     fi
   done
   echo "\n\n"
   if [ -f /data/system/users/${UserID[iUser]}/accounts.db ]; then
     sqlite3 /data/system/users/${UserID[iUser]}/accounts.db < /data/jpchil/jAndBackup/jAndAccounts.sql
   fi
   # Jetzt automatisch wg. /data/user/0/com.android.providers.userdictionary/databases/user_dict.db
   sqlite3 /data/data/com.android.providers.userdictionary/databases/user_dict.db < /data/jpchil/jAndBackup/jAndUserdict.sql
   tar -czf - /data/local/tmp/accounts.dmp /data/local/tmp/userdictionary.dmp \
          /data/system_de/${UserID[iUser]}/accounts_de.db  /data/system_ce/${UserID[iUser]}/accounts_ce.db \
          /data/system/sync/accounts.xml /data/misc/bluedroid /data/misc/wifi \
          /data/misc_ce/${UserID[iUser]}/wifi 2>>$LogFile | /system/xbin/gpg --batch --yes --encrypt --recipient joerg@jpchil.at -o $BackupDir/misc-User${UserID[iUser]}.tgg
   rm /data/local/tmp/accounts.dmp /data/local/tmp/userdictionary.dmp
done
rm /data/local/tmp/base.apk

echo "`date +%Y%m%d-%H%M` - batchBackup finished" >> $LogFile
