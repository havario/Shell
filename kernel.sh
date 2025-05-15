#!/usr/bin/env bash
#
# Description: This script is used to automatically install the latest Linux kernel version.
#
# Copyright (c) 2025 honeok <honeok@duck.com>
#
# Thanks: Teddysun <i@teddysun.com>
#
# Licensed under the Apache License, Version 2.0.
# Distributed on an "AS IS" basis, WITHOUT WARRANTIES.
# See http://www.apache.org/licenses/LICENSE-2.0 for details.

# https://www.graalvm.org/latest/reference-manual/ruby/UTF8Locale
export LANG=en_US.UTF-8
# 环境变量用于在debian或ubuntu操作系统中设置非交互式 (noninteractive) 安装模式
export DEBIAN_FRONTEND=noninteractive
# 设置PATH环境变量
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH

# 自定义彩色字体
_red() { printf "\033[91m%s\033[0m\n" "$*"; }
_green() { printf "\033[92m%s\033[0m\n" "$*"; }
_yellow() { printf "\033[93m%s\033[0m\n" "$*"; }
_err_msg() { printf "\033[41m\033[1mError\033[0m %s\n" "$*"; }
_suc_msg() { printf "\033[42m\033[1mSuccess\033[0m %s\n" "$*"; }
_info_msg() { printf "\033[43m\033[1mInfo\033[0m %s\n" "$*"; }
reading() { read -rep "$(_yellow "$1")" "$*"; }

# 安全清屏函数
clear_screen() {
    [ -t 1 ] && tput clear 2>/dev/null || echo -e "\033[2J\033[H" || clear
}

error_and_exit() {
    _err_msg "$(_red "$@")" >&2 && exit 1
}

_is_exists() {
    local _CMD="$1"
    if type "$_CMD" >/dev/null 2>&1;then return 0
    elif command -v "$_CMD" >/dev/null 2>&1;then return 0
    elif which "$_CMD" >/dev/null 2>&1;then return 0
    else return 1
    fi
}

_is_alpine() {
    [ -f /etc/alpine-release ]
}

_os_full() {
    if [ -s /etc/os-release ]; then
        OS_INFO="$(grep -i '^PRETTY_NAME=' /etc/os-release | awk -F'=' '{print $NF}' | sed 's#"##g')"
    elif [ -x "$(type -p hostnamectl)" ]; then
        OS_INFO="$(hostnamectl | grep -i system | cut -d: -f2 | xargs)"
    elif [ -x "$(type -p lsb_release)" ]; then
        OS_INFO="$(lsb_release -sd 2>/dev/null)"
    elif [ -s /etc/lsb-release ]; then
        OS_INFO="$(grep -i description /etc/lsb-release 2>/dev/null | cut -d \" -f2)"
    elif [ -s /etc/redhat-release ]; then
        OS_INFO="$(grep . /etc/redhat-release)"
    elif [ -s /etc/issue ]; then
        OS_INFO="$(grep . /etc/issue | cut -d '\' -f1 | sed '/^[ ]*$/d')"
    fi
    declare -a RELEASE=("almalinux" "alpine" "centos" "debian" "fedora" "rhel" "rocky" "ubuntu")
    declare -a RELEASE_REGEX=("almalinux" "alpine" "centos" "debian" "fedora" "red hat|rhel" "rocky" "ubuntu")
    for linux in "${!RELEASE_REGEX[@]}"; do
        [[ "${OS_INFO,,}" =~ "${RELEASE_REGEX[linux]}" ]] && OS_NAME="${RELEASE[linux]}" && break
    done
    [ -z "$OS_NAME" ] && error_and_exit 'This Linux distribution is not supported.'
}

_os_version() {
    local MAIN_VER
    MAIN_VER="$(printf "%s" "$OS_INFO" | grep -oE "[0-9.]+")"
    printf -- "%s" "${MAIN_VER%%.*}"
}

detect_virt() {
    local VIRT
    if _exists "virt-what"; then
        VIRT="$(virt-what)"
    elif _exists "systemd-detect-virt"; then
        VIRT="$(systemd-detect-virt)"
    else
        error_and_exit 'No virtualization detection tool found.'
    fi
    declare -a UNSUPPORTED=("lxc" "openvz" "docker")
    for type in "${UNSUPPORTED[@]}"; do
        if [[ "${VIRT,,}" =~ "$type" ]] || [[ "$type" == "openvz" && -d "/proc/vz" ]]; then
            error_and_exit "Virtualization method is $type, which is not supported."
        fi
    done
}