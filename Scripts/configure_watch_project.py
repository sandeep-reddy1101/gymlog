#!/usr/bin/env python3
"""Add/update Watch wiring while preserving the existing iPhone target and signing settings."""
from pathlib import Path
import hashlib
import json
import subprocess
import sys
from xml.sax.saxutils import escape

root = Path(__file__).resolve().parents[1]
project = root / 'LiftLog.xcodeproj/project.pbxproj'
value = json.loads(subprocess.check_output(['plutil', '-convert', 'json', '-o', '-', str(project)]))
objects = value['objects']
def uid(key): return hashlib.sha1(('watch-support:' + key).encode()).hexdigest()[:24].upper()
def add(key, isa, **fields):
    ident = uid(key)
    objects[ident] = dict(isa=isa, **fields)
    return ident
def append(items, item):
    if item not in items: items.append(item)
def file_ref(path, typ):
    found = next((i for i, o in objects.items() if o.get('isa') == 'PBXFileReference' and o.get('path') == path), None)
    return found or add(path, 'PBXFileReference', lastKnownFileType=typ, path=path, sourceTree='SOURCE_ROOT')
p = objects[value['rootObject']]
phone_id = next(i for i in p['targets'] if objects[i].get('name') == 'LiftLog')
phone = objects[phone_id]
phone_sources = next(objects[i] for i in phone['buildPhases'] if objects[i]['isa'] == 'PBXSourcesBuildPhase')
main = objects[p['mainGroup']]['children']
phone_configs = [objects[i] for i in objects[phone['buildConfigurationList']]['buildConfigurations']]
# Record existing configuration values so additions cannot reset user-selected team/bundle identity.
preserved = {c['name']: dict(c['buildSettings']) for c in phone_configs}
for path in sorted((root / 'LiftLog').rglob('*.swift')):
    relative = str(path.relative_to(root))
    ref = file_ref(relative, 'sourcecode.swift')
    append(main, ref)
    if not any(objects[i].get('fileRef') == ref for i in phone_sources['files']):
        append(phone_sources['files'], add('phone-build:' + relative, 'PBXBuildFile', fileRef=ref))
watch_files = [str(f.relative_to(root)) for f in sorted((root / 'GymLogWatch').glob('*.swift'))]
watch_files.append('LiftLog/Core/WatchWorkout.swift')
watch_builds = []
for path in watch_files:
    ref = file_ref(path, 'sourcecode.swift'); append(main, ref)
    watch_builds.append(add('watch-build:' + path, 'PBXBuildFile', fileRef=ref))
for path in ['GymLogWatch/Resources/Info.plist', 'GymLogWatch/Resources/GymLogWatch.entitlements']:
    append(main, file_ref(path, 'text.plist.xml'))
assets = file_ref('GymLogWatch/Resources/Assets.xcassets', 'folder.assetcatalog'); append(main, assets)
asset_build = add('watch-assets-build', 'PBXBuildFile', fileRef=assets)
product = add('product', 'PBXFileReference', explicitFileType='wrapper.application', includeInIndex='0', path='GymLogWatch.app', sourceTree='BUILT_PRODUCTS_DIR')
append(objects[p['productRefGroup']]['children'], product)
sources = add('sources', 'PBXSourcesBuildPhase', buildActionMask='2147483647', files=watch_builds, runOnlyForDeploymentPostprocessing='0')
resources = add('resources', 'PBXResourcesBuildPhase', buildActionMask='2147483647', files=[asset_build], runOnlyForDeploymentPostprocessing='0')
frameworks = add('frameworks', 'PBXFrameworksBuildPhase', buildActionMask='2147483647', files=[], runOnlyForDeploymentPostprocessing='0')
configs = []
for config in phone_configs:
    old = config['buildSettings']; name = config['name']; local = name.endswith('Local')
    settings = dict(
        PRODUCT_NAME='GymLogWatch', PRODUCT_BUNDLE_IDENTIFIER=old['PRODUCT_BUNDLE_IDENTIFIER'] + '.watchkitapp',
        GYMLOG_COMPANION_BUNDLE_IDENTIFIER=old['PRODUCT_BUNDLE_IDENTIFIER'],
        CODE_SIGN_STYLE=old.get('CODE_SIGN_STYLE', 'Automatic'), DEVELOPMENT_TEAM=old.get('DEVELOPMENT_TEAM', ''),
        CODE_SIGN_ENTITLEMENTS='LiftLog/Resources/LocalOnly.entitlements' if local else 'GymLogWatch/Resources/GymLogWatch.entitlements',
        GENERATE_INFOPLIST_FILE='NO', INFOPLIST_FILE='GymLogWatch/Resources/Info.plist',
        CURRENT_PROJECT_VERSION=old.get('CURRENT_PROJECT_VERSION', '1'), MARKETING_VERSION=old.get('MARKETING_VERSION', '1.0'),
        SDKROOT='watchos', WATCHOS_DEPLOYMENT_TARGET='10.0', TARGETED_DEVICE_FAMILY='4',
        SUPPORTED_PLATFORMS='watchos watchsimulator', SKIP_INSTALL='YES', SWIFT_VERSION='5.0',
        ASSETCATALOG_COMPILER_APPICON_NAME='AppIcon', LD_RUNPATH_SEARCH_PATHS='$(inherited) @executable_path/Frameworks',
    )
    configs.append(add('config:' + name, 'XCBuildConfiguration', name=name, buildSettings=settings))
config_list = add('configs', 'XCConfigurationList', buildConfigurations=configs, defaultConfigurationIsVisible='0', defaultConfigurationName='Release')
target = add('target', 'PBXNativeTarget', name='GymLogWatch', productName='GymLogWatch', productType='com.apple.product-type.application', productReference=product, buildConfigurationList=config_list, buildPhases=[sources, frameworks, resources], buildRules=[], dependencies=[])
append(p['targets'], target)
p.setdefault('attributes', {}).setdefault('TargetAttributes', {}).setdefault(target, {'CreatedOnToolsVersion':'27.0'})
proxy = add('proxy', 'PBXContainerItemProxy', containerPortal=value['rootObject'], proxyType='1', remoteGlobalIDString=target, remoteInfo='GymLogWatch')
dependency = add('dependency', 'PBXTargetDependency', target=target, targetProxy=proxy)
append(phone['dependencies'], dependency)
embed_build = add('embed-build', 'PBXBuildFile', fileRef=product, settings={'ATTRIBUTES':['RemoveHeadersOnCopy']})
embed = add('embed', 'PBXCopyFilesBuildPhase', buildActionMask='2147483647', dstPath='$(CONTENTS_FOLDER_PATH)/Watch', dstSubfolderSpec='16', files=[embed_build], name='Embed Watch Content', runOnlyForDeploymentPostprocessing='0')
append(phone['buildPhases'], embed)
assert all(preserved[c['name']] == c['buildSettings'] for c in phone_configs)

def render(obj, depth=0):
    tab = '\t' * depth
    if isinstance(obj, dict):
        return '{\n' + ''.join('\t'*(depth+1) + json.dumps(k) + ' = ' + render(v, depth+1) + ';\n' for k,v in obj.items()) + tab + '}'
    if isinstance(obj, list):
        return '(\n' + ''.join('\t'*(depth+1) + render(v, depth+1) + ',\n' for v in obj) + tab + ')'
    return json.dumps(str(obj))
project.write_text('// !$*UTF8*$!\n' + render(value) + '\n')
reference = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="GymLogWatch.app" BlueprintName="GymLogWatch" ReferencedContainer="container:LiftLog.xcodeproj"/>'
scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{reference}</BuildActionEntry></BuildActionEntries></BuildAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>'''
(root / 'LiftLog.xcodeproj/xcshareddata/xcschemes/Gym Log Watch.xcscheme').write_text(scheme)
print('Added Watch target and embedded companion; all existing iPhone build settings preserved.')
