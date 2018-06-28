#!/bin/sh

jazzyRepo=dougzilla32.github.io
currentDir=`pwd`
module=$(basename "$currentDir")

case $module in
    CancelForPromiseKit)
      ;;
    Alamofire|CoreLocation|Foundation)
      module=CPK$module;;
    *)
      echo "Invalid module name: $module"; exit 1;;
    esac

if [ -d $module.xcworkspace ] ; then
  workspaceOrProject=-workspace,$module.xcworkspace
else
  workspaceOrProject=-project,$module.xcodeproj
fi

while [ "$currentDir" != "/" -a ! -d "$currentDir/$jazzyRepo" ] ; do
  currentDir=$(dirname "$currentDir")
done
if [ "$currentDir" == "/" ] ; then
  echo "Repo $jazzyRepo not found in current directory or in parent directory"
  exit 1
fi
repo="$currentDir/$jazzyRepo"

jazzy \
  --clean \
  --output "$repo/$module/api" \
  --xcodebuild-arguments $workspaceOrProject,-scheme,$module,SWIFT_VERSION=4.1,-destination,"arch=x86_64",SWIFT_TREAT_WARNINGS_AS_ERRORS=YES,build
