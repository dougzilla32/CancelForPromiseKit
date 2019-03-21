#!/bin/sh

jazzy_repo=dougzilla32.github.io

if which jazzy >/dev/null; then
  if [ -d $jazzy_repo/CancelForPromiseKit ] ; then
    echo jazzy --clean --output $jazzy_repo/CancelForPromiseKit/api --xcodebuild-arguments -workspace,CancelForPromiseKit.xcworkspace,-scheme,CancelForPromiseKit,SWIFT_VERSION=4.1,-destination,"arch=x86_64",SWIFT_TREAT_WARNINGS_AS_ERRORS=YES,build
  else
    echo "warning: jazzy docs output directory '$jazzy_repo/CancelForPromiseKit' not there, remedy by cloning 'https://github.com/dougzilla32/$jazzy_repo' at the CancelForPromiseKit top-level"
  fi

  for extension in Extensions/*/CPK*.xcodeproj/project.pbxproj ; do
    projectDir="$(dirname $extension)"
    project="$(basename $projectDir)"
    scheme="$(basename $projectDir .xcodeproj)"
    (cd "$projectDir/.." ;
     output_parent=../../$jazzy_repo/$project
     if [ -d $output_parent ] ; then
       echo jazzy --clean --output $output_parent/api --xcodebuild-arguments -project,$project,-scheme,$scheme,SWIFT_VERSION=4.1,-destination,"arch=x86_64",SWIFT_TREAT_WARNINGS_AS_ERRORS=YES,build
     else
       echo "warning: jazzy docs output directory '$jazzy_repo/$project' not there, remedy by cloning 'https://github.com/dougzilla32/$jazzy_repo' at CancelForPromiseKit top-level"
     fi)
  done
else
  echo "warning: jazzy not installed, install with '[sudo] gem install jazzy'"
fi
