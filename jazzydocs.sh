#!/bin/sh

jazzy \
  --clean \
  --author Doug \
  --author_url https://github.com/dougzilla32 \
  --github_url https://github.com/dougzilla32/CancelForPromiseKit \
  --github-file-prefix https://github.com/dougzilla32/CancelForPromiseKit/tree/master \
  --module-version 1.0.0 \
  --module CancelForPromiseKit \
  --root-url https://github.com/dougzilla32/CancelForPromiseKit/api \
  --output api \
  --xcodebuild-arguments -workspace,CancelForPromiseKit.xcworkspace,-scheme,CancelForPromiseKit,SWIFT_VERSION=4.1,-destination,"arch=x86_64",SWIFT_TREAT_WARNINGS_AS_ERRORS=YES,build
