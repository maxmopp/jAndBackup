#!/system/bin/sh
#
# 201900215
# 20191005  add $User
#
# needs files jAndBackupPackage.Ignore and jAndBackup.Exclude

# backup single package

# $1  .... package to restore
# $2  .... user to restore it for

PATH=/system/xbin:$PATH

# export LD_LIBRARY_PATH=/vendor/lib*:/system/lib*:/data/jpchil/lib
export HOME=/data/jpchil/

Verzeichnis=/sdcard/jAndBackup

if [ "$2" == "" ]; then echo "User spec missing"; exit; fi
Result=$(pm list packages --user $2)                                                                             
if [ "$Result" == "" ]; then echo "No such user: $2"; fi


if [ "$1" == "" ]; then echo "Package spec *name* "; exit; fi
# format: /data/app/org.mozilla.firefox-sEyzX8YPNS21UfboL73Ntg== --> org.mozilla.firefox
Package=$(find /data/app/ -type d -iname "*$1*"  | tail -1 | sed 's/.*\/\(.*\).\{25\}/\1/')
if [ "$Package" == "" ]; then echo "Package $Package not found"; exit; fi
printf "Backup $Package (Y/N)"
read YesNo
Answer=$(echo $YesNo | tr '[:lower:]' '[:upper:]')
if [ "$Answer" != "Y" ]; then exit; fi

echo "Saving $Package, $Package System and User data"

####### apk
tar -X /data/jpchil/jAndBackup/jAndBackup.Exclude -czf $BackupDir/$jPackage-apk.tgz \
  /data/app/*$jPackage*/

####### system data
tar -X /data/jpchil/jAndBackup/jAndBackup.Exclude -czf - \
  /data/data/*$jPackage*/ 2>>$LogFile | \
  /system/xbin/gpg --batch --yes --encrypt --recipient joerg@jpchil.at -o $BackupDir/$jPackage-System.tgg

####### user data
tar -X /data/jpchil/jAndBackup/jAndBackup.Exclude -czf - \
  /data/user/$iUser/*$jPackage*/ /data/user_de/$iUser/*$jPackage*/ 2>>$LogFile | \
  /system/xbin/gpg --batch --yes --encrypt --recipient joerg@jpchil.at -o $BackupDir/$jPackage-User${UserID[iUser]}.
