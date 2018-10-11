#!/bin/sh

# MIT License
#
# Copyright (c) 2018 0x1306a94

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

TMP_PATH="/var/tmp"

PlistBuddy=/usr/libexec/PlistBuddy

BUILD_WORKSPACE="$TMP_PATH/BuildWorkspace"
ARCHIVE_PATH="$BUILD_WORKSPACE/Archive"
BUILD_PATH="$BUILD_WORKSPACE/Build"
EXPORT_PATH="$BUILD_WORKSPACE/Export"
CONFIG_PATH="$BUILD_WORKSPACE/BuildConfig"

TEMPLATE_PLIST='<?xml version="1.0" encoding="UTF-8"?>\n
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n
<plist version="1.0">\n
<dict>\n
</dict>\n
</plist>
'

PROJECT_NAME=
WORKSPACE_NAME=
SCHEMES_FILE="${BUILD_WORKSPACE}/schemes.json"
BUILD_SETTING_FILE="${BUILD_WORKSPACE}/build_setting.json"
MAKE_FILE="`pwd`/Makefile"
IS_WORKSPACE=0
CONFIGURATAION="Release"
EXPORT_METHOD="ad-hoc"

function checkEnvironment() {
    # echo "checkEnvironment...."
    if [[ ! `uname` -eq "Darwin" ]]; then
        echo "此脚本仅支持 macOS 系统"
        exit 0
    fi
}

function checkTools() {
    # echo "checkTools...."
    hash jq
    if [[ $? != 0 ]]; then
        echo "请先安装 jq 命令行工具, 因为此脚本需要使用 jq 命令行工具"
        echo "你可以使用 homebrew 安装  brew install jq"
        exit 0
    fi

    hash make
    if [[ $? != 0 ]]; then
        echo "请先安装 make 命令行工具, 因为此脚本需要使用 make 命令行工具"
        echo "你可以使用 homebrew 安装  brew install make"
        exit 0
    fi
}

function checkProjectPath() {
    # echo "checkProjectPath...."
    PROJECT_NAME=`ls | grep ".xcodeproj"`
    if [[ ${#PROJECT_NAME} -eq 0 ]]; then
        echo "请将此脚本放置 工程 xcodeproj 文件同级目录"
        exit 0
    fi
}

function checkWorkspacePath() {
    # echo "checkWorkspacePath...."
    WORKSPACE_NAME=`ls | grep ".xcworkspace"`
    if [[ ! ${#WORKSPACE_NAME} -eq 0 ]]; then
        IS_WORKSPACE=1
    fi
}

function checkBuildWorkspacePath() {

    if [[ ! -d $ARCHIVE_PATH ]]; then
        mkdir -p $ARCHIVE_PATH
    fi

    if [[ ! -d $BUILD_PATH ]]; then
        mkdir -p $BUILD_PATH
    fi

    if [[ ! -d $EXPORT_PATH ]]; then
        mkdir -p $EXPORT_PATH
    fi

    if [[ ! -d $CONFIG_PATH ]]; then
        mkdir -p $CONFIG_PATH
    fi

}

function checkBuildSettins() {
    if [[ -f $BUILD_SETTING_FILE ]]; then
        rm $BUILD_SETTING_FILE
    fi
    xcodebuild -project $1 -scheme $2 -configuration $3 -showBuildSettings > ${BUILD_SETTING_FILE}
}

function generate_prepare() {
    makeTarget=".PHONY: prepare"
    makeTarget=${makeTarget//\"/""}
    buildLine="prepare:"
    buildLine=${buildLine//\"/""}
    echo $makeTarget >> $MAKE_FILE
    echo $buildLine >> $MAKE_FILE
    echo "\t@mkdir -p $ARCHIVE_PATH $BUILD_PATH $EXPORT_PATH $CONFIG_PATH\n" >> $MAKE_FILE
}

function generate_build() {
    # build
    makeTarget=".PHONY: build-$1"
    makeTarget=${makeTarget//\"/""}
    buildLine="build-$1: prepare"
    buildLine=${buildLine//\"/""}
    echo $makeTarget >> $MAKE_FILE
    echo $buildLine >> $MAKE_FILE
    if [[ $IS_WORKSPACE -eq 1 ]]; then
        command="\t@xcodebuild clean build -derivedDataPath ${BUILD_PATH} -workspace ${WORKSPACE_NAME} -scheme $1 -configuration $2 \n\n"
        # command=${command//\"/""}
        echo $command >> $MAKE_FILE
    else
        command="\t@xcodebuild clean build -derivedDataPath ${BUILD_PATH} -project ${PROJECT_NAME} -scheme $1 -configuration $2 \n\n"
        # command=${command//\"/""}
        echo $command >> $MAKE_FILE
    fi
}

# $1 scheme
# $2 archive path
# $3 build path
# $4 configuration
function generate_archive() {
    # archive
    makeTarget=".PHONY: archive-$1"
    makeTarget=${makeTarget//\"/""}
    buildLine="archive-$1: prepare"
    buildLine=${buildLine//\"/""}
    echo $makeTarget >> $MAKE_FILE
    echo $buildLine >> $MAKE_FILE
    if [[ $IS_WORKSPACE -eq 1 ]]; then
        command="\t@xcodebuild clean archive -archivePath ${2} -derivedDataPath ${3} -workspace ${WORKSPACE_NAME} -scheme ${1} -configuration ${4} \n\n"
        # command=${command//\"/""}
        echo $command >> $MAKE_FILE
    else
        command="\t@xcodebuild clean archive -archivePath ${2} -derivedDataPath ${3} -project ${PROJECT_NAME} -scheme ${1} -configuration ${4} \n\n"
        # command=${command//\"/""}
        echo $command >> $MAKE_FILE
    fi
}

# $1 scheme
# $2 archive path
# $3 export path
# $4 export plist path
# $5 ipa name
# $6 export ipa path
function generate_ipa() {
    # generate ipa
    makeTarget=".PHONY: generate-$1"
    makeTarget=${makeTarget//\"/""}
    buildLine="generate-$1: archive-$1 generate-${1}-export-plist"
    buildLine=${buildLine//\"/""}
    echo $makeTarget >> $MAKE_FILE
    echo $buildLine >> $MAKE_FILE
    if [[ $IS_WORKSPACE -eq 1 ]]; then
        command="\t@xcodebuild -exportArchive -archivePath ${2} -exportPath $3 -exportOptionsPlist $4"
        # command=${command//\"/""}
        echo $command >> $MAKE_FILE
    else
        command="\t@xcodebuild -exportArchive -archivePath ${2} -exportPath $3 -exportOptionsPlist $4"
        # command=${command//\"/""}
        echo $command >> $MAKE_FILE
    fi
    echo '\t@echo "cpoy ipa file ......."' >> $MAKE_FILE
    echo "\t@cp -r $3/\`ls /var/tmp/BuildWorkspace/Export/TDXDLoginModule-Example-Release | grep \".ipa\"\` $6 \n\n" >> $MAKE_FILE
}

# $1 scheme
# $2 buundle id
# $3 team id
# $4 provisioningProfile
# $5 method
function generate_export_plist() {
    # team id
    # echo "generate_export_plist ..."
    PLIST_PATH=$CONFIG_PATH/$1-export.plist

    makeTarget=".PHONY: generate-${1}-export-plist"
    makeTarget=${makeTarget//\"/""}
    buildLine="generate-${1}-export-plist:"
    buildLine=${buildLine//\"/""}
    echo $makeTarget >> $MAKE_FILE
    echo $buildLine >> $MAKE_FILE
    echo "\t@echo \"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\" > $PLIST_PATH" >> $MAKE_FILE
    echo "\t@echo \"<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\" >> $PLIST_PATH" >> $MAKE_FILE
    echo "\t@echo \"<plist version=\"1.0\"> >> $PLIST_PATH\"" >> $MAKE_FILE
    echo "\t@echo \"<dict>\" >> $PLIST_PATH" >> $MAKE_FILE
    echo "\t@echo \"</dict>\" >> $PLIST_PATH" >> $MAKE_FILE
    echo "\t@echo \"</plist>\" >> $PLIST_PATH" >> $MAKE_FILE

    echo "\t@/usr/libexec/PlistBuddy -c 'Add :provisioningProfiles dict' $PLIST_PATH" >> $MAKE_FILE
    echo "\t@/usr/libexec/PlistBuddy -c 'Add :provisioningProfiles:${2} string ${4}' $PLIST_PATH" >> $MAKE_FILE
    echo "\t@/usr/libexec/PlistBuddy -c 'Add :signingStyle string \"manually\"' $PLIST_PATH" >> $MAKE_FILE
    echo "\t@/usr/libexec/PlistBuddy -c 'Add :teamID string ${3}' $PLIST_PATH" >> $MAKE_FILE
    echo "\t@/usr/libexec/PlistBuddy -c 'Add :method string ${5}' $PLIST_PATH\n\n" >> $MAKE_FILE

    # $PlistBuddy -c 'Add :provisioningProfiles dict' $PLIST_PATH
    # $PlistBuddy -c "Add :provisioningProfiles:${2} string ${4}" $PLIST_PATH
    # $PlistBuddy -c 'Add :signingStyle string "manually"' $PLIST_PATH
    # $PlistBuddy -c "Add :teamID string ${3}" $PLIST_PATH
    # $PlistBuddy -c "Add :method string ${5}" $PLIST_PATH
}

function generate_clean() {
    # generate clean
    makeTarget=".PHONY: clean"
    makeTarget=${makeTarget//\"/""}
    buildLine="clean:"
    buildLine=${buildLine//\"/""}
    echo $makeTarget >> $MAKE_FILE
    echo $buildLine >> $MAKE_FILE
    echo "\t@rm -rf $BUILD_WORKSPACE \n" >> $MAKE_FILE
}

function forEcahSchemes() {
    # echo "forEcahSchemes...."
    schemes=`xcodebuild -list -project ${PROJECT_NAME} -json | jq ".project.schemes"`
    idx=0
    flag=1
    if [[ -f $MAKE_FILE ]]; then
            rm $MAKE_FILE
    fi

    while true
    do
        scheme=`echo $schemes | jq ".[${idx}]"`
        if [[ $scheme == "null" ]]; then
            flag=0
            break
        fi

        idx=`expr $idx + 1`

        scheme=${scheme//\"/""}

        checkBuildSettins $PROJECT_NAME $scheme $CONFIGURATAION

        if [[ ! -f $BUILD_SETTING_FILE ]]; then
            continue
        fi

        MACH_O_TYPE=`grep -w "MACH_O_TYPE = mh_execute" ${BUILD_SETTING_FILE}`
        # app mh_execute, 静态库 staticlib, 动态库 mh_dylib
        if [[ -z $MACH_O_TYPE ]]; then
            continue
        fi

        BUNDLE_ID=`grep -w "PRODUCT_BUNDLE_IDENTIFIER" ${BUILD_SETTING_FILE}`
        BUNDLE_ID=${BUNDLE_ID//"PRODUCT_BUNDLE_IDENTIFIER = "/""}

        DEVELOPMENT_TEAM_ID=`grep -w "DEVELOPMENT_TEAM" ${BUILD_SETTING_FILE}`
        DEVELOPMENT_TEAM_ID=${DEVELOPMENT_TEAM_ID//"DEVELOPMENT_TEAM = "/""}
        DEVELOPMENT_TEAM_ID=${DEVELOPMENT_TEAM_ID//" "/""}

        PROVISIONING_PROFILE_SPECIFIER=`grep -w "PROVISIONING_PROFILE_SPECIFIER" ${BUILD_SETTING_FILE}`
        PROVISIONING_PROFILE_SPECIFIER=${PROVISIONING_PROFILE_SPECIFIER//"PROVISIONING_PROFILE_SPECIFIER = "/""}

        PRODUCT_NAME=`grep -w "PRODUCT_NAME" ${BUILD_SETTING_FILE}`
        PRODUCT_NAME=${PRODUCT_NAME//"PRODUCT_NAME = "/""}

        # echo "generate ...."
        # generate_build $scheme $CONFIGURATAION
        generate_prepare
        generate_archive $scheme ${ARCHIVE_PATH}/${scheme}-$CONFIGURATAION ${BUILD_PATH} $CONFIGURATAION
        generate_export_plist $scheme $BUNDLE_ID $DEVELOPMENT_TEAM_ID $PROVISIONING_PROFILE_SPECIFIER $EXPORT_METHOD
        generate_ipa $scheme  ${ARCHIVE_PATH}/${scheme}-$CONFIGURATAION.xcarchive "$EXPORT_PATH/$scheme-$CONFIGURATAION" "$CONFIG_PATH/$scheme-export.plist" $PRODUCT_NAME $PWD
        echo "使用 make generate-$scheme 命令生成 $PRODUCT_NAME.ipa"
    done

    if [[ $flag -eq 0 && $idx -eq 0 ]]; then
        echo "无法读取工程 scheme 信息, 请检查工程配置"
        exit 0
    fi

    generate_clean
}

checkEnvironment

checkTools

checkProjectPath

checkWorkspacePath

checkBuildWorkspacePath

forEcahSchemes
