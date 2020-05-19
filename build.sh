rm -rf ./archive-Fire.xcarchive
rm -rf apps
xcodebuild archive -workspace Fire.xcworkspace -scheme Fire -archivePath ./archive-Fire -configuration Release
mkdir apps
cp -a ./archive-Fire.xcarchive/Products/Applications/*.app apps
ditto -c -k --sequesterRsrc --keepParent apps/Fire.app apps/Fire.zip
rm -rf /Library/Input\ Methods/Fire.app
cp -r /Users/chenqiang/Documents/github/Fire/apps/Fire.app /Library/Input\ Methods/
