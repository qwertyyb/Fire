#!/bin/bash

download_url='https://github.com/qwertyyb/Fire/releases/latest/download/FireInstaller.pkg'

version=$(git describe --tags `git rev-list --tags --max-count=1`)

str=$(./Pods/Sparkle/bin/sign_update -s "${sparkle_key}" ./apps/FireInstaller.pkg)

sign=$(echo $str | grep "edSignature=\"[^\"]*" -o | grep "\"[^\"]*" -o)
sign=${sign#\"}

length=$(echo $str | grep "length=\"[^\"]*" -o | grep "\"[^\"]*" -o)
length=${length#\"}

echo "${sign}";
echo "${length}"


CFBundleVersion=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" Fire/Info.plist)

echo "${version}"
echo "${CFBundleVersion}"

cat>./apps/appcast.xml<<EOF
<?xml version="1.0" standalone="yes"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
    <channel>
        <title>Fire</title>
        <item>
            <title>${version}</title>
            <pubDate>$(date -R)</pubDate>
            <sparkle:minimumSystemVersion>10.15</sparkle:minimumSystemVersion>
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