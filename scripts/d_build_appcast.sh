#!/bin/bash

PROJECT_ROOT="$(cd "$(dirname "$BASH_SOURCE")/.."; pwd)"
source "$PROJECT_ROOT/scripts/common.sh"

if [[ ${sparkle_key} == "" ]]
then
    echo "Error: No Sparkle key"
    exit 1
fi

download_url='https://github.com/qwertyyb/Fire/releases/latest/download/FireInstaller.zip'

version=$(git describe --tags `git rev-list --tags --max-count=1`)

str=$($PROJECT_ROOT/bin/sign_update -s "${sparkle_key}" "$EXPORT_INSTALLER_ZIP")

sign=$(echo $str | grep "edSignature=\"[^\"]*" -o | grep "\"[^\"]*" -o)
sign=${sign#\"}

length=$(echo $str | grep "length=\"[^\"]*" -o | grep "\"[^\"]*" -o)
length=${length#\"}

echo "${sign}";
echo "${length}"

if [[ $sign == "" ]]
then
    echo "Sign Failed: no sign"
    exit 1
fi


CFBundleVersion=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$PROJECT_ROOT/Fire/Info.plist")

echo "${version}"
echo "${CFBundleVersion}"

cat>$EXPORT_PATH/appcast.xml<<EOF
<?xml version="1.0" standalone="yes"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
    <channel>
        <title>${APP_NAME}</title>
        <item>
            <title>${version}</title>
            <pubDate>$(date -R)</pubDate>
            <sparkle:minimumSystemVersion>10.15</sparkle:minimumSystemVersion>
            <description><![CDATA[
                ${update_notes}
            ]]>
            </description>
            <enclosure url="${download_url}"
              sparkle:version="${CFBundleVersion}"
              sparkle:shortVersionString="${version}"
              length="${length}"
              sparkle:edSignature="${sign}"
              type="application/octet-stream"/>
        </item>
    </channel>
</rss>
EOF