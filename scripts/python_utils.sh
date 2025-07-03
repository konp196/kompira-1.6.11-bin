#!/bin/bash
shopt -s extglob
THIS_DIR=$(dirname $(readlink -f $0))
. $THIS_DIR/setup_utils.sh

#
# Python 3.X 対応表 (追加リポジトリまたは事前コマンド)
# --------------------+--------------+--------------+--------------+------------------+--------------------------------------+-------------------------------------------------+-------------------------------------------
# RPM package         | CentOS9      | RHEL9        | CentOS8(*1)  | RHEL8            | CentOS7                              | RHEL7                                           | AmazonLinux2
# --------------------+--------------+--------------+--------------+------------------+--------------------------------------+-------------------------------------------------+-------------------------------------------
# python3.11          | 3.11.4 (!!)  | 3.11.2       | 3.11.4 (!!)  | --               | --                                   | --                                              | --
# --------------------+--------------+--------------+--------------+------------------+--------------------------------------+-------------------------------------------------+-------------------------------------------
# python3.9           | 3.9.17 (!!)  | 3.9.16       | --           | --               | --                                   | --                                              | --
# --------------------+--------------+--------------+--------------+------------------+--------------------------------------+-------------------------------------------------+-------------------------------------------
# python39            | --           | --           | 3.9.17 (!!)  | [RH] 3.9.16      | --                                   | --                                              | --
#                     |              |              |              | [AZ] 3.9.7       |                                      |                                                 |
#                     |              |              |              | [AWS] 3.9.16     |                                      |                                                 |
# --------------------+--------------+--------------+--------------+------------------+--------------------------------------+-------------------------------------------------+-------------------------------------------
# python38            | --           | --           | 3.8.17 (!!)  | [RH] 3.8.16      | --                                   | --                                              | 3.8.16 
#                     |              |              |              | [AZ] 3.8.12      |                                      |                                                 | # amazon-linux-extras enable python3.8
#                     |              |              |              | [AWS] 3.8.16     |                                      |                                                 |
# --------------------+--------------+--------------+--------------+------------------+--------------------------------------+-------------------------------------------------+-------------------------------------------
# rh-python38-python  | --           | --           | --           | --               | 3.8.13                               | [RH] 3.8.14 (rhel-server-rhscl-7-rpms)          | 3.8.13                 
# (SCL)               |              |              |              |                  | # yum install centos-release-scl-rh  | [AZ] 3.8.14 (rhel-server-rhui-rhscl-7-rpms)     | # yum install centos-release-scl-rh
#                     |              |              |              |                  |                                      | [AWS] 3.8.14 (rhel-server-rhui-rhscl-7-rpms)    | [not recommended]
# --------------------+--------------+--------------+--------------+------------------+--------------------------------------+-------------------------------------------------+-------------------------------------------
# python3  (3.7)      | --           | --           | --           | --               | --                                   | --                                              | 3.7.16
# --------------------+--------------+--------------+--------------+------------------+--------------------------------------+-------------------------------------------------+-------------------------------------------
# python3  (3.6)      | --           | --           | --           | --               | 3.6.8                                | [RH] 3.6.8 (rhel-7-server-optional-rpms)        | --
# [not recommended]   |              |              |              |                  |                                      | [AZ] Not installable! (*3)                      |
#                     |              |              |              |                  |                                      | [AWS] 3.6.8 (rhel-7-server-rhui-optional-rpms)  |
# --------------------+--------------+--------------+--------------+------------------+--------------------------------------+-------------------------------------------------+-------------------------------------------
# python36            | --           | --           | 3.6.8 (!!)   | [RH] 3.6.8 (!!)  | --                                   | --                                              | --
#                     |              |              |              | [AZ] 3.6.8 (!!)  |                                      |                                                 |
#                     |              |              |              | [AWS] 3.6.8 (!!) |                                      |                                                 |
# --------------------+--------------+--------------+--------------+------------------+--------------------------------------+-------------------------------------------------+-------------------------------------------
# rh-python36-python  | --           | --           | --           | --               | 3.6.12                               | [RH] 3.6.12 (rhel-server-rhscl-7-rpms)          | 3.6.12                 
# (SCL)               |              |              |              |                  | # yum install centos-release-scl-rh  | [AZ] 3.6.12 (rhel-server-rhui-rhscl-7-rpms)     | # yum install centos-release-scl-rh
#                     |              |              |              |                  |                                      | [AWS] 3.6.12 (rhel-server-rhui-rhscl-7-rpms)    | [not recommended]
# --------------------+--------------+--------------+--------------+------------------+--------------------------------------+-------------------------------------------------+-------------------------------------------
#
# (!!) debuginfo-install python3～ に失敗する
#   debuginfo-install --enablerepo="*debuginfo" python38
#   debuginfo-install --enablerepo="*debuginfo" python3.9
# (*1) Rocky Linux 8.8, Alma Linux 8.8, MIRACLE Linux 8.6 は CentOS8 に同じ
# (*2) rhel-7-server-optional-rpms または rhel-7-server-rhui-optional-rpms
# (*3) RHUIのレポジトリの問題で、Python3のインストールに失敗する場合、--rhel-option-repoオプション引数で、python3-develの含まれるレポジトリを指定するか、
#      それでも上手くいかない場合は、事前に手動でpython3/python3-develをインストールしておき、--skip-python3-install オプションを指定してインストールする。
#
# [CentOS7 @ Azure]
# yum-config-manager --disable rhel-ha-for-rhel-7-server-eus-rhui-rpms

declare -A AVAILABLE_PYVERS=(
    # Python3.11 は当面サポート対象外
    ["RHEL9"]="3.9"
    ["CENT9"]="3.9"
    ["ROCKY9"]="3.9"
    ["ALMA9"]="3.9"
    ["MIRACLE9"]="3.9"
    ["AMZN2023"]="3.9"
    ["CENT8"]="3.9 3.8 3.6"
    ["RHEL8"]="3.9 3.8 3.6"
    ["CENT7"]="3.8 3.6"
    ["RHEL7"]="3.8 3.6"
    ["AMZN2"]="3.8 3.7"
    ["ROCKY8"]="3.9 3.8"
    ["ALMA8"]="3.9 3.8"
    ["MIRACLE8"]="3.9 3.8"
)
declare -A PYTHON_PACKAGE_INFO=(
    ["CENT9_PY311"]='PACKAGE=python3.11; DEBUGINFO_REPO="*debuginfo"'
    ["RHEL9_PY311"]='PACKAGE=python3.11'
    ["CENT8_PY311"]='PACKAGE=python3.11; DEBUGINFO_REPO="*debuginfo"'
    ["ROCKY9_PY311"]='PACKAGE=python3.11; DEBUGINFO_REPO="*debug*"'
    ["ALMA9_PY311"]='PACKAGE=python3.11; DEBUGINFO_REPO="*debuginfo"'
    ["MIRACLE9_PY311"]='PACKAGE=python3.11'
    ["AMZN2023_PY311"]='PACKAGE=python3.11'

    ["CENT9_PY39"]='PACKAGE=python3.9; DEBUGINFO_REPO="*debuginfo"'
    ["RHEL9_PY39"]='PACKAGE=python3.9'
    ["CENT8_PY39"]='PACKAGE=python39; DEBUGINFO_REPO="*debuginfo"'
    ["RHEL8_PY39"]='PACKAGE=python39'
    ["ROCKY9_PY39"]='PACKAGE=python3.9; DEBUGINFO_REPO="*debug*"'
    ["ALMA9_PY39"]='PACKAGE=python3.9; DEBUGINFO_REPO="*debuginfo"'
    ["MIRACLE9_PY39"]='PACKAGE=python3.9'
    ["ROCKY8_PY39"]='PACKAGE=python39; DEBUGINFO_REPO="*debug*"'
    ["ALMA8_PY39"]='PACKAGE=python39; DEBUGINFO_REPO="*debuginfo"'
    ["MIRACLE8_PY39"]='PACKAGE=python39'
    ["AMZN2023_PY39"]='PACKAGE=python3.9'

    ["CENT8_PY38"]='PACKAGE=python38; DEBUGINFO_REPO="*debuginfo"'
    ["RHEL8_PY38"]='PACKAGE=python38'
    ["CENT7_PY38"]='PACKAGE=rh-python38-python; DEBUGINFO_REPO="*debuginfo"; PREPARE_COMMAND="yum -y install --disablerepo=pgdg* centos-release-scl-rh"'
    ["RHEL7_PY38"]='PACKAGE=rh-python38-python; REQUIRE_REPO="*-rhscl-7-rpms"'
    ["AMZN2_PY38"]='PACKAGE=python38; PREPARE_COMMAND="env PYTHON= amazon-linux-extras enable python3.8"'
    ["ROCKY8_PY38"]='PACKAGE=python38; DEBUGINFO_REPO="*debug*"'
    ["ALMA8_PY38"]='PACKAGE=python38; DEBUGINFO_REPO="*debuginfo"'
    ["MIRACLE8_PY38"]='PACKAGE=python38'

    ["AMZN2_PY37"]='PACKAGE=python3'

    ["CENT8_PY36"]='PACKAGE=python36; DEBUGINFO_PACKAGE=platform-python'
    ["RHEL8_PY36"]='PACKAGE=python36; DEBUGINFO_PACKAGE=platform-python'
    ["CENT7_PY36"]='PACKAGE=rh-python36-python; PREPARE_COMMAND="yum -y install --disablerepo=pgdg* centos-release-scl-rh"'
    ["RHEL7_PY36"]='PACKAGE=rh-python36-python; REQUIRE_REPO="*-rhscl-7-rpms"'
)

: ${SYSNAME:=$(echo "$SYSTEM_NAME" | tr a-z A-Z)}
PREPARE_ONLY_MODE=false
QUIET_MODE=false
OFFLINE_MODE=false
DEBUGINFO_MODE=true
DOWNLOAD_MODE=false
DOWNLOAD_DEST=./python_packages
DRY_RUN=false


element_in()
{
    local value=$1
    local elem
    shift
    for elem; do [[ "$elem" == "$value" ]] && return 0; done
    return 1
}

available_pyvers()
{
    echo "${AVAILABLE_PYVERS[$SYSNAME]}"
}

python_package_info()
{
    local sysname=$1
    local pyver=$2
    local pyver_nodot=${pyver/./}
    local package_info=${PYTHON_PACKAGE_INFO["${sysname}_PY${pyver_nodot}"]}
    echo "$package_info"
}

info_python()
{
    local found=0
    if [ -z "$*" ]; then
        set "all"
    fi
    for pyver in $(available_pyvers); do
        if [[ "$*" =~ "$pyver" ]] || [[ "$*" =~ "all" ]]; then
            python_package_info $SYSNAME $pyver
        fi
    done
}

which_python()
{
    local found=0
    if [ -z "$*" ]; then
        set "all"
    fi
    for pyver in $(available_pyvers); do
        if [[ "$*" =~ "$pyver" ]] || [[ "$*" =~ "all" ]]; then
            local PACKAGE="" REQUIRE_REPO="" PREPARE_COMMAND="" DEBUGINFO_REPO="" DEBUGINFO_PACKAGE=""
            eval $(python_package_info $SYSNAME $pyver)
            if [ -z "$PACKAGE" ]; then
                continue
            fi
            local python_bin="python${pyver}"
            local python_path=""
            case "$PACKAGE" in
                rh-*-python) 
                    local scl_collection=$(echo $PACKAGE | sed -re 's/-python$//')
                    python_path=$(scl enable $scl_collection -- which $python_bin 2>/dev/null || echo_warn "scl collection \"$scl_collection\" cannot be enabled!">/dev/stderr) ;;
                *)
                    python_path=$(which $python_bin 2>/dev/null || echo_error "$python_bin not found!">/dev/stderr) ;;
            esac
            if [ -n "$python_path" ]; then
                echo "$python_path"
                found=$((found+1))
            fi
        fi
    done
    if [ $found -eq 0 ]; then
        echo_error "No available python installed!">/dev/stderr
        exit 1
    fi
}

install_python()
{
    local pyver cmnd
    local PYTHON_VERSIONS=()
    local PYTHON_PACKAGES=()
    local DEBUGINFO_PACKAGES=("glibc")
    local DEBUGINFO_REPOS=()
    local REQUIRE_REPOS=()
    local PREPARE_COMMANDS=()
    local INSTALL_COMMANDS=()
    local available_pyvers=$(available_pyvers)
    local found=0
    if [ -z "$*" ]; then
        echo_error "You must specify at least one version of python that you want to install (available: $available_pyvers), or specify \"all\""
        exit 1
    fi
    for pyver in $available_pyvers; do
        if [[ "$*" =~ "$pyver" ]] || [[ "$*" =~ "all" ]]; then
            local PACKAGE="" REQUIRE_REPO="" PREPARE_COMMAND="" DEBUGINFO_REPO="" DEBUGINFO_PACKAGE=""
            eval $(python_package_info $SYSNAME $pyver)
            if [ -z "$PACKAGE" ]; then
                continue
            fi
            PYTHON_VERSIONS+=("$pyver")
            PYTHON_PACKAGES+=("${PACKAGE}-devel")
            if ! $OFFLINE_MODE; then
                if ! element_in "$DEBUGINFO_REPO" "${DEBUGINFO_REPOS[@]}" && $DEBUGINFO_MODE; then
                    DEBUGINFO_REPOS+=("$DEBUGINFO_REPO")
                fi
                if ! element_in "$REQUIRE_REPO" "${REQUIRE_REPOS[@]}"; then
                    REQUIRE_REPOS+=("$REQUIRE_REPO")
                fi
                if ! element_in "$PREPARE_COMMAND" "${PREPARE_COMMANDS[@]}"; then
                    PREPARE_COMMANDS+=("$PREPARE_COMMAND")
                fi
            fi
            if $DEBUGINFO_MODE; then
                if [ -z "$DEBUGINFO_PACKAGE" ]; then
                    DEBUGINFO_PACKAGE="$PACKAGE"
                fi
                DEBUGINFO_PACKAGES+=("$DEBUGINFO_PACKAGE")
            fi
            found=$((found+1))
        fi
    done
    if [ $found -eq 0 ]; then
        echo_error "Specified version of python is not supported. (available: $available_pyvers)"
        exit 1
    fi

    # generate command lines
    local yum_options="-y"
    local debuginfo_options="-y"
    local repotrack_options=""
    local additional_options=""
    if $OFFLINE_MODE; then
        yum_options="$yum_options --noplugins --disablerepo=* --enablerepo=$KOMPIRA_EXTRA_NAME"
        debuginfo_options="$debuginfo_options --disablerepo=* --enablerepo=$KOMPIRA_EXTRA_NAME"
    elif [ "$SYSTEM" != "AMZN" ]; then
        additional_options="--disablerepo=pgdg*"
    fi
    if $DEBUGINFO_MODE || [ $RHEL_VERSION == 7 ]; then
        INSTALL_COMMANDS+=("yum $yum_options $additional_options install yum-utils")
    fi
    if ! $OFFLINE_MODE; then
        for repo in "${REQUIRE_REPOS[@]}"; do
            if [ -n "$repo" ]; then
                yum_options+=" --enablerepo=$repo"
            fi
        done
        debuginfo_options+=" --nogpgcheck"
        for repo in "${DEBUGINFO_REPOS[@]}"; do
            if [ -n "$repo" ]; then
                debuginfo_options+=" --enablerepo=$repo"
            fi
        done
    fi
    if $DOWNLOAD_MODE; then
        if [ $RHEL_VERSION == 7 ]; then
            repotrack_options+="-p $DOWNLOAD_DEST"
            # The old repotrack command does not support the yum option.
            # So, enable the repository with the yum-config-manager command.
            # yum-config-manager is provides by yum-utils.
            for repo in "${REQUIRE_REPOS[@]}"; do
                cmnd="yum-config-manager --enable $repo"
                if ! element_in "$cmnd" "${INSTALL_COMMANDS[@]}"; then
                    INSTALL_COMMANDS+=("$cmnd")
                fi
            done
        else
            repotrack_options+="$yum_options $additional_options --destdir=$DOWNLOAD_DEST --alldeps --resolve"
        fi
        INSTALL_COMMANDS+=("mkdir -p $DOWNLOAD_DEST")
        INSTALL_COMMANDS+=("repotrack $repotrack_options ${PYTHON_PACKAGES[*]}")
        if $DEBUGINFO_MODE; then
            INSTALL_COMMANDS+=("debuginfo-install $debuginfo_options $additional_options --downloadonly --downloaddir=$DOWNLOAD_DEST ${DEBUGINFO_PACKAGES[*]}")
        fi
    else
        INSTALL_COMMANDS+=("yum $yum_options $additional_options install ${PYTHON_PACKAGES[*]}")
        if $DEBUGINFO_MODE; then
            INSTALL_COMMANDS+=("debuginfo-install $debuginfo_options $additional_options ${DEBUGINFO_PACKAGES[*]}")
        fi
    fi
    # print variables
    if ! $QUIET_MODE; then
        echo "PYTHON_VERSIONS=\"${PYTHON_VERSIONS[@]}\""
        echo "PYTHON_PACKAGES=\"${PYTHON_PACKAGES[@]}\""
        echo "PYTHON_REQUIRE_REPOS=\"${REQUIRE_REPOS[@]}\""
        echo "PYTHON_DEBUGINFO_PACKAGES=\"${DEBUGINFO_PACKAGES[@]}\""
        echo "PYTHON_DEBUGINFO_REPOS=\"${DEBUGINFO_REPOS[@]}\""        
    fi
    # execute prepare commands
    for cmnd in "${PREPARE_COMMANDS[@]}" "--" "${INSTALL_COMMANDS[@]}"; do
        if [ -z "$cmnd" ]; then
            true
        elif [ "$cmnd" == "--" ]; then
            if $PREPARE_ONLY_MODE; then
                break
            fi
        elif $DRY_RUN; then
            echo $cmnd
        else
            verbose_run $cmnd
        fi
    done
}

usage_exit()
{
    cat <<EOF
Usage: $(basename "$0") [options] command args...
options:
  --destdir DESTDIR             Set directory to download packages to
  --prepare-only                Execute only the preparation process.
  --offline                     Install in offline mode using the kompira-extra package.
  --dry-run                     Check the parameters without actually installing.
  --help                        Show this message.

command:
  available                     Show available python versions
  info [pyver...]               Show information about python packages
  install [pyver...]            Install python packages
  download [pyver...]           Download python packages
  script [pyver...]             Generate scripts for install or download python packages
  which [pyver...]
EOF
    exit 1
}

parse_options()
{
    OPTIONS=$(getopt -q -o '' -l destdir:,prepare-only,offline,without-debuginfo,quiet,debug,dry-run,help -- "$@")
    [ $? != 0 ] && usage_exit
    eval set -- "$OPTIONS"
    while true
    do
        arg="$1"
        case "$arg" in
            --destdir) DOWNLOAD_DEST=$2; shift ;;
            --prepare-only) PREPARE_ONLY_MODE=true ;;
            --offline) OFFLINE_MODE=true ;;
            --without-debuginfo) DEBUGINFO_MODE=false ;;
            --quiet) QUIET_MODE=true ;;
            --dry-run) DRY_RUN=true ;;
            --) shift; break ;;
            *) usage_exit ;;
        esac
        shift
    done
    OPTIONS=$(getopt -q -o '' "$@")
}

main()
{
    parse_options "$@"
    eval set $OPTIONS
    local command=$1; shift

    if [ -z "${AVAILABLE_PYVERS[$SYSNAME]}" ]; then
        echo_error "System name \"$SYSNAME\" not supported!"
        exit 1
    fi
    case $command in
        available) available_pyvers ;;
        info) info_python "$@" ;;
        install) install_python "$@" ;;
        download) DOWNLOAD_MODE=true; install_python "$@" ;;
        which) which_python "$@" ;;
        *) usage_exit ;;
    esac
}

set -eo pipefail
main "$@"
