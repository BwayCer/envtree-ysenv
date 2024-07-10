#!/bin/env python3

import hashlib
import os
import subprocess
import sys
import yaml


_origArgs = sys.argv
_fileDir = os.path.dirname(os.path.abspath(__file__))
_filename = os.path.basename(__file__)

helpTxt = '''\
環境設定文件解析器
Usage:
    edit
    <host|docker> --list
    <host|docker> [實例] --list
    host <實例>
    docker <實例>
Opt:
  -h, --help   幫助.
'''

__hostHome = os.environ['HOME']

__baseErrMsg = '環境設定文件格式不正確.'

__fieldOfString = {'name', 'image', 'user'}
__fieldOfBoolean = {'dock'}
__fieldOfArray = {'volume', 'rc'}


def main():
    envConfigPath = pathJoin(_fileDir, './config.yaml')

    action, groups, instance = __parseCmdArgs(_origArgs)

    if action == 'Help' or action == 'NeedHelp':
        sysPrintExit(0 if action == 'Help' else 1, helpTxt)

    if action == 'edit':
        sysPrintExit(0, f'vi {envConfigPath!r}')
    elif not os.path.exists(envConfigPath):
        sysPrintExit(1, f'請先 `{_filename} edit` 編輯環境設定文件.')

    exitCode, envConfig = loadConfig(envConfigPath)
    if exitCode != 0:
        sysPrintExit(exitCode, envConfig)

    exitCode, txt = __matchProcess(envConfig, action, groups, instance)
    sysPrintExit(exitCode, txt)


def __parseCmdArgs(cmdArgs: tuple[str, ...]) -> tuple[str, str, str]:
    isNeedHelp = True
    argsLength = len(cmdArgs)
    action = ''
    groups = ''
    instance = ''
    if '-h' in cmdArgs or '--help' in cmdArgs:
        action = 'Help'
    elif argsLength > 1:
        match cmdArgs[1]:
            case 'edit':
                isNeedHelp = False
                action = 'edit'
            case 'host' | 'docker' if 2 < argsLength < 5 and cmdArgs[2] != '':
                isNeedHelp = False

                isHasOptList = cmdArgs[argsLength - 1] == '--list'
                action = 'List' if isHasOptList else 'Build'

                groups = cmdArgs[1] + 's'
                if not cmdArgs[2].startswith('--'):
                    instance = cmdArgs[2]

    if isNeedHelp:
        action = 'NeedHelp'

    return action, groups, instance


def loadConfig(filePath: str) -> tuple[int, str]:
    '載入環境設定文件.'
    try:
        with open(filePath, 'r', encoding='utf-8') as fs:
            data = yaml.load(fs, Loader=yaml.SafeLoader)
        return 0, data

    except Exception as err:
        return 1, err


def __matchProcess(
    envConfig: dict,
    action: str,
    groupListName: str,
    instanceName: str,
) -> tuple[int, str]:
    errMsg = __checkEnvConfigXxBase(envConfig)
    if errMsg is not None:
        return 1, errMsg

    groups = envConfig[groupListName]
    groupsKeys = groups.keys()

    # instanceName 為空值, 則 action 必為 List
    if instanceName == '':
        return 0, ' '.join(groupsKeys)
    elif instanceName not in groups:
        return (
            1,
            f'找不到 "{instanceName}" 實例. (允許值: {", ".join(groupsKeys)})'
        )

    instanceId = f'{groupListName}.{instanceName}'
    exitCode, info \
        = __getGroupDetails(envConfig, groupListName, instanceName)
    if exitCode != 0:
        return 1, info

    # `os.path.expanduser()` 只接受 `~` 無法辨別 `$HOME`.
    basePath = os.path.expanduser(envConfig['basePath'])

    return (
        __listGroupDetails if action == 'List'
        else __listHostOpt if groupListName == 'hosts'
        else __listDockerRunOpt
    )(instanceId, basePath, info)


def __checkEnvConfigXxBase(envConfig: dict) -> [None | str]:
    level01Type = {
        'basePath': str,
        'groupParts': dict,
        'hosts': dict,
        'dockers': dict,
    }
    for key, val in level01Type.items():
        if key not in envConfig or not isinstance(envConfig[key], val):
            return f'{__baseErrMsg} ("{key}" 欄位遺失或格式錯誤)'


def __checkEnvConfigXxMergeGroupParts(
    instanceId: str,
    mergeItems: object,
    allowList: list,
) -> [None | str]:
    if not isinstance(mergeItems, list):
        return f'{__baseErrMsg} ({instanceId} 的 "groups" 欄位格式必須為 `Array`.)'

    allowList = set(allowList)
    mergeItems = set(mergeItems)

    # 怕有 None 而出錯
    notExistGroups = list(map(str, mergeItems - allowList))
    if len(notExistGroups) > 0:
        return (
            f'{__baseErrMsg} ("{instanceId}" 有不存在的'
            f' "{'", "'.join(notExistGroups)}" 群組)'
        )


def __getGroupDetails(
    envConfig: dict,
    instanceListName: str,
    instanceName: str,
) -> tuple[int, [str | dict]]:
    groupParts = envConfig['groupParts']
    instance = envConfig[instanceListName][instanceName]
    instanceId = f'{instanceListName}.{instanceName}'

    if not isinstance(instance, dict):
        return 1, f'找不到 "{instanceId}" 實例. (未設定選項)'

    if 'groupParts' in instance:
        mergeParts = instance['groupParts']
        errMsg = __checkEnvConfigXxMergeGroupParts(
            instanceId, mergeParts, groupParts.keys(),
        )
        if errMsg is not None:
            return 1, errMsg

        mergeItems = \
            [[f'groupParts.{item}', groupParts[item]] for item in mergeParts] \
            + [['instance', instance]]
    else:
        mergeItems = [['instance', instance]]

    newInfo = {}
    for item in mergeItems:
        theId = item[0]
        theInfo = item[1]

        if not isinstance(theInfo, dict):
            return 1, f'{__baseErrMsg} ({instanceId} 的 {theId} 的格式錯誤)'

        errMsg = __mergeGroup(newInfo, theId, theInfo)
        if errMsg is not None:
            return 1, f'{__baseErrMsg} ({instanceId} 的 {errMsg})'

    # 在 dockers 的 instance 中設定 `vmHome` 欄位.
    vmHome = ''
    if instanceListName == 'dockers':
        if 'image' not in newInfo:
            return 1, f'{__baseErrMsg} ({instanceId} 找不到指定映像文件)'

        if 'vmHome' not in newInfo:
            vmHome = __getDockerContainerHomePath(
                newInfo['image']['value'],
                user=newInfo['user']['value'] if 'user' in newInfo else None,
            )

            newInfo['vmHome'] = {'value': vmHome, 'from': 'via container'}

    elif instanceListName == 'hosts':
        if not ('volume' in newInfo or 'rc' in newInfo):
            return (
                1,
                f'{__baseErrMsg} ({instanceId} 是空白任務 (沒有 `volume`, `rc`))'
            )

    errMsg = __mergeVolume(newInfo, vmHome)
    if errMsg is not None:
        return 1, f'{__baseErrMsg} ({instanceId} 的 {errMsg})'

    return 0, newInfo


def __isList(obj: object) -> bool:
    return isinstance(obj, list)


def __mergeGroup(info: dict, srcId: str, src: dict) -> [None | str]:
    errMsg = '"{}" 欄位格式必須為 `{}`'
    skipList = {'groupParts'}
    for key, val in src.items():
        if key in skipList:
            pass
        elif key in __fieldOfString:
            if isinstance(val, str):
                info[key] = {'value': f'{val}', 'from': srcId}
                if val.strip() == '':
                    return f'"{key}" 欄位不得為空值.'
            else:
                return errMsg.format(key, 'String')
        elif key in __fieldOfBoolean:
            if isinstance(val, bool):
                info[key] = {'value': val, 'from': srcId}
            else:
                return errMsg.format(key, 'Boolean')
        elif key in __fieldOfArray:
            if __isList(val):
                pushValue = [
                    {'value': value, 'from': srcId}
                    for value in val if value is not None
                ]
                if key in info:
                    info[key] += pushValue
                else:
                    info[key] = pushValue
            else:
                return errMsg.format(key, 'Array')
        else:
            if key in info and isinstance(key, type(info[key].value)):
                return f'"{key}" 欄位前後格式不一'

            if __isList(val) and key in info and __isList(info[key]):
                pushValue = [{'value': value, 'from': srcId} for value in val]
                info[key] += pushValue
            else:
                info[key] = {'value': val, 'from': srcId}


def __mergeVolume(info: dict, vmHome: str = '') -> [None | str]:
    if 'volume' not in info:
        return

    # `vmHome + '/'` 解決 `os.path.normpath()` 不處理 `//` 出現在首字母的問題.
    vmHome = __hostHome if vmHome == '' else (vmHome + '/')
    volumeList = info['volume'].copy()

    for item in volumeList:
        value = item['value']
        fromGroup = item['from']

        splitValueList = value.split(':')
        splitValueListLength = len(splitValueList)
        if splitValueListLength < 2:
            return f'{fromGroup} 的 {value!r} 格式錯誤'

        hostPath = splitValueList[0]
        vmPath = splitValueList[1]

        if hostPath.startswith('~/'):
            hostPath = hostPath.replace('~', __hostHome, 1)
        if vmPath.startswith('~/'):
            vmPath = vmPath.replace('~', vmHome, 1)

        item['hostPath'] = os.path.normpath(hostPath)
        item['vmPath'] = os.path.normpath(vmPath)
        item['permission'] \
            = splitValueList[2] if splitValueListLength == 3 else ''

    # 排除相同路徑, 父目錄路徑, 後面覆蓋前面
    pickPaths = []
    newVolumeList = []
    for item in sorted(volumeList[::-1], key=__sortVolumeKey, reverse=True):
        vmPath = item['vmPath']

        isContinue = False
        for refItem in pickPaths:
            if vmPath == refItem or refItem.startswith(vmPath + '/'):
                isContinue = True
                break
        if isContinue:
            continue

        pickPaths.append(vmPath)
        newVolumeList.append(item)

    info['volume'] = newVolumeList[::-1]


def __sortVolumeKey(item: dict) -> int:
    return len(item['vmPath'])


def __getDockerContainerHomePath(
    image: str,
    user: [None | str],
) -> dict:
    '''
    取得容器內家目錄路徑.

    `--rm` 會使 `docker run` 退出時花一段時間，具體秒數約 0~6 秒不等
    '''

    dockerCmdList = ['docker', 'run', '--rm']

    if user is not None:
        dockerCmdList += ['--user', user]

    cmdList = dockerCmdList.copy() + [image, 'sh', '-c', 'echo $HOME']
    # `capture_output=True`:
    #   相當於同時設定了 `stdout=subprocess.PIPE` 和
    #   `stderr=subprocess.PIPE` 用於捕獲命令的標準輸出和標準錯誤, 並通过
    #   `result.stdout` 和 `result.stderr` 屬性訪問.
    # `text=True`:  (或 universal_newlines=True)
    #   將原本捕獲的位元 (bytes) 格式標準輸出解碼為字串.
    result = subprocess.run(cmdList, capture_output=True, text=True)
    containerHome = result.stdout.strip()

    return containerHome


def __listGroupDetails(
    instanceId: str,
    basePath: str,
    info: dict,
) -> tuple[int, str]:
    skipList = {'image', 'vmHome', 'notOnce', 'volume', 'rc'}
    isDocker = instanceId.startswith('dockers.')

    showMsgs = [f'basePath: {basePath}']

    if isDocker:
        showMsgs += [
            f'{key}: {info[key]['value']}   (by {info[key]['from']})'
            for key in ['vmHome', 'image']
        ]
        showMsgs += ['']

    if isDocker:
        showMsgs += ['Set option:']

        showMsgs += [
            '  --rm   (by default)'
            if 'notOnce' not in info or info['notOnce']['value'] is not True
            else f'  #notOnce   (by {info['notOnce']['from']})'
        ]

        for key, val in info.items():
            if key in skipList:
                continue

            if isinstance(val, list):
                showMsgs += [
                    f'   --{key} = {subVal['value']}   (by {subVal['from']})'
                    for subVal in val
                ]
            else:
                value = val['value']
                fromGroup = val['from']
                showMsgs += [
                    f'  --{key}'
                    + ('' if isinstance(value, bool) else f' = {value}')
                    + f'   (by {fromGroup})'
                ]

        showMsgs += ['']

    if 'volume' in info:
        volumeInfo = info['volume']

        showMsgs += ['Volume list:']
        maxLetterLength = sorted(map(__sortVolumeKey, volumeInfo))[-1]
        for item in volumeInfo:
            hostPath = item['hostPath']
            vmPath = item['vmPath']
            # permission = item['permission']
            fromGroup = item['from']
            showMsgs += [
                f'  {vmPath:<{maxLetterLength}s}'
                f' --> {hostPath}   (by {fromGroup})'
            ]

        showMsgs += ['']

    if 'rc' in info:
        rcInfo = info['rc']

        showMsgs += ['rc file:']
        currFromGroup = ''
        for item in rcInfo:
            cmd = item['value']
            fromGroup = item['from']
            if currFromGroup != fromGroup:
                currFromGroup = fromGroup
                showMsgs += [f'  (by {fromGroup})']
            showMsgs += [f'    {cmd}']

        showMsgs += ['']

    return 0, '\n'.join(showMsgs)


def __listHostOpt(
    instanceId: str,
    basePath: str,
    info: dict,
) -> tuple[int, str]:
    return 0, ''


def __listDockerRunOpt(
    instanceId: str,
    basePath: str,
    info: dict,
) -> tuple[int, str]:
    return 0, ''


def sysPrintExit(exitCode: int, txt: str):
    print(txt, file=None if exitCode == 0 else sys.stderr)
    exit(exitCode)


def pathJoin(root: str, *args: tuple[str, ...]) -> str:
    '把路徑依平台分隔符重新組合.'
    pathParts = []
    for thePath in args:
        for part in thePath.split('/'):
            pathParts.append(part)
    return os.path.normpath(os.path.join(root, *pathParts))


if __name__ == '__main__':
    main()
