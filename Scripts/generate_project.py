#!/usr/bin/env python3
"""Regenerate the checked-in Xcode project using only Python's standard library."""
from pathlib import Path
import hashlib
import json
import plistlib
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
# Normal use updates source/Watch wiring without erasing user-selected signing settings.
if (root / 'LiftLog.xcodeproj/project.pbxproj').exists() and '--fresh' not in sys.argv:
    subprocess.run([sys.executable, str(root / 'Scripts/configure_watch_project.py')], check=True)
    raise SystemExit(0)
def uid(value): return hashlib.sha1(value.encode()).hexdigest()[:24].upper()
def q(value): return json.dumps(value)
objects = []
def obj(key, body):
    objects.append(f'\t\t{uid(key)} = {{ {body} }};')
    return uid(key)
sources = sorted((root / 'LiftLog').rglob('*.swift'))
file_ids, build_ids = [], []
for file in sources:
    relative = str(file.relative_to(root))
    file_ids.append(obj(relative, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {q(relative)}; sourceTree = SOURCE_ROOT;'))
    build_ids.append(obj('build:' + relative, f'isa = PBXBuildFile; fileRef = {uid(relative)};'))
for relative in ['LiftLog/Resources/Info.plist', 'LiftLog/Resources/LiftLog.entitlements', 'LiftLog/Resources/LocalOnly.entitlements', 'README.md', 'SETUP.md', 'REQUIREMENTS.md', 'docs/VALIDATION.md']:
    file_ids.append(obj(relative, f'isa = PBXFileReference; path = {q(relative)}; sourceTree = SOURCE_ROOT;'))
assets = 'LiftLog/Resources/Assets.xcassets'
file_ids.append(obj(assets, f'isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = {q(assets)}; sourceTree = SOURCE_ROOT;'))
asset_build = obj('build:' + assets, f'isa = PBXBuildFile; fileRef = {uid(assets)};')
product = obj('product', 'isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = LiftLog.app; sourceTree = BUILT_PRODUCTS_DIR;')
products = obj('products', f'isa = PBXGroup; name = Products; children = ({product},); sourceTree = "<group>";')
main_group = obj('group', f'isa = PBXGroup; children = ({",".join(file_ids + [products])},); sourceTree = "<group>";')
sources_phase = obj('sources', f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(build_ids)},); runOnlyForDeploymentPostprocessing = 0;')
frameworks_phase = obj('frameworks', 'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
resources_phase = obj('resources', f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({asset_build},); runOnlyForDeploymentPostprocessing = 0;')
configs = ['Debug', 'Release', 'DebugLocal', 'ReleaseLocal']
project_configs, target_configs = [], []
for name in configs:
    debug = name.startswith('Debug')
    local = name.endswith('Local')
    settings = {
        'CLANG_ENABLE_MODULES': 'YES', 'CLANG_ENABLE_OBJC_ARC': 'YES',
        'SDKROOT': 'iphoneos', 'IPHONEOS_DEPLOYMENT_TARGET': '17.0',
        'SWIFT_VERSION': '5.0', 'SWIFT_OPTIMIZATION_LEVEL': '-Onone' if debug else '-O',
        'DEBUG_INFORMATION_FORMAT': 'dwarf' if debug else 'dwarf-with-dsym',
        'ENABLE_TESTABILITY': 'YES' if debug else 'NO',
        'SWIFT_ACTIVE_COMPILATION_CONDITIONS': '$(inherited)' + (' DEBUG' if debug else '') + ('' if local else ' HEALTHKIT_ENABLED'),
    }
    project_configs.append(obj('project:' + name, f'isa = XCBuildConfiguration; name = {q(name)}; buildSettings = {{' + ''.join(f'{k} = {q(v)};' for k,v in settings.items()) + '};'))
    target = {
        'PRODUCT_NAME': 'LiftLog', 'PRODUCT_BUNDLE_IDENTIFIER': 'com.yourname.LiftLog',
        'CODE_SIGN_STYLE': 'Automatic', 'CODE_SIGN_ENTITLEMENTS': 'LiftLog/Resources/LocalOnly.entitlements' if local else 'LiftLog/Resources/LiftLog.entitlements',
        'GENERATE_INFOPLIST_FILE': 'NO', 'INFOPLIST_FILE': 'LiftLog/Resources/Info.plist',
        'CURRENT_PROJECT_VERSION': '1', 'MARKETING_VERSION': '1.0',
        'ASSETCATALOG_COMPILER_APPICON_NAME': 'AppIcon',
        'TARGETED_DEVICE_FAMILY': '1', 'SUPPORTED_PLATFORMS': 'iphoneos iphonesimulator',
        'SUPPORTS_MACCATALYST': 'NO', 'ENABLE_PREVIEWS': 'YES',
        'LD_RUNPATH_SEARCH_PATHS': '$(inherited) @executable_path/Frameworks',
    }
    target_configs.append(obj('target:' + name, f'isa = XCBuildConfiguration; name = {q(name)}; buildSettings = {{' + ''.join(f'{k} = {q(v)};' for k,v in target.items()) + '};'))
project_list = obj('projectConfigs', f'isa = XCConfigurationList; buildConfigurations = ({",".join(project_configs)},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
target_list = obj('targetConfigs', f'isa = XCConfigurationList; buildConfigurations = ({",".join(target_configs)},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
target_id = obj('target', f'isa = PBXNativeTarget; buildConfigurationList = {target_list}; buildPhases = ({sources_phase},{frameworks_phase},{resources_phase},); buildRules = (); dependencies = (); name = LiftLog; productName = LiftLog; productReference = {product}; productType = "com.apple.product-type.application";')
project_id = obj('project', f'isa = PBXProject; attributes = {{ LastSwiftUpdateCheck = 1600; LastUpgradeCheck = 1600; TargetAttributes = {{ {target_id} = {{ CreatedOnToolsVersion = 16.0; }}; }}; }}; buildConfigurationList = {project_list}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en,Base,); mainGroup = {main_group}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = ({target_id},);')
project_dir = root / 'LiftLog.xcodeproj'
project_dir.mkdir(exist_ok=True)
(project_dir / 'project.pbxproj').write_text('// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {};\n\tobjectVersion = 56;\n\tobjects = {\n' + '\n'.join(objects) + f'\n\t}};\n\trootObject = {project_id};\n}}\n')
reference = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target_id}" BuildableName="LiftLog.app" BlueprintName="LiftLog" ReferencedContainer="container:LiftLog.xcodeproj"/>'
for name, config, demo in [('Lift Log', 'Debug', False), ('Lift Log Local Only', 'DebugLocal', False), ('Lift Log Demo', 'DebugLocal', True)]:
    args = '<CommandLineArguments><CommandLineArgument argument="--demo" isEnabled="YES"/></CommandLineArguments>' if demo else ''
    scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{reference}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="{config}" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables/></TestAction>
<LaunchAction buildConfiguration="{config}" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable>{args}</LaunchAction>
<ProfileAction buildConfiguration="{'Release' if config == 'Debug' else 'ReleaseLocal'}" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="{config}"/><ArchiveAction buildConfiguration="{'Release' if config == 'Debug' else 'ReleaseLocal'}" revealArchiveInOrganizer="YES"/>
</Scheme>'''
    destination = project_dir / 'xcshareddata/xcschemes' / f'{name}.xcscheme'
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(scheme)
subprocess.run([sys.executable, str(root / 'Scripts/configure_watch_project.py')], check=True)
print(f'Generated project with {len(sources)} iPhone Swift files, Watch companion, and four shared schemes.')
