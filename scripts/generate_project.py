"""Generate the checked-in Xcode project using only Python's standard library."""
from pathlib import Path
import hashlib
import json
import plistlib

ROOT = Path(__file__).resolve().parents[1]
def ident(value):
    return hashlib.sha256(value.encode()).hexdigest()[:24].upper()

def generate():
    objects = {}
    def add(key, **fields):
        key = ident(key); objects[key] = fields; return key
    sources = []
    refs = []
    for file in sorted((ROOT / 'ios').rglob('*.swift')):
        path = file.relative_to(ROOT).as_posix()
        ref = add('ref:' + path, isa='PBXFileReference', lastKnownFileType='sourcecode.swift', path=path, sourceTree='<group>')
        refs.append(ref)
        sources.append(add('build:' + path, isa='PBXBuildFile', fileRef=ref))
    resource_builds = []
    for path, kind in [('ios/App/Assets.xcassets', 'folder.assetcatalog'), ('ios/App/PrivacyInfo.xcprivacy', 'text.xml')]:
        ref = add('ref:' + path, isa='PBXFileReference', lastKnownFileType=kind, path=path, sourceTree='<group>')
        refs.append(ref)
        resource_builds.append(add('build:' + path, isa='PBXBuildFile', fileRef=ref))
    product = add('product', isa='PBXFileReference', explicitFileType='wrapper.application', path='ShabbatTV.app', sourceTree='BUILT_PRODUCTS_DIR')
    products = add('products', isa='PBXGroup', children=[product], name='Products', sourceTree='<group>')
    group = add('root', isa='PBXGroup', children=refs + [products], sourceTree='<group>')
    source_phase = add('sources', isa='PBXSourcesBuildPhase', buildActionMask=2147483647, files=sources, runOnlyForDeploymentPostprocessing=0)
    frameworks = add('frameworks', isa='PBXFrameworksBuildPhase', buildActionMask=2147483647, files=[], runOnlyForDeploymentPostprocessing=0)
    resources = add('resources', isa='PBXResourcesBuildPhase', buildActionMask=2147483647, files=resource_builds, runOnlyForDeploymentPostprocessing=0)
    configs = []; project_configs = []
    for name in ['Debug', 'Release']:
        settings = dict(PRODUCT_NAME='ShabbatTV', PRODUCT_BUNDLE_IDENTIFIER='com.shabbattv.ipad',
            INFOPLIST_FILE='ios/App/Info.plist', GENERATE_INFOPLIST_FILE='NO',
            SWIFT_VERSION='5.0', IPHONEOS_DEPLOYMENT_TARGET='17.0', TARGETED_DEVICE_FAMILY='2',
            SDKROOT='iphoneos', SUPPORTED_PLATFORMS='iphoneos iphonesimulator',
            SUPPORTS_MACCATALYST='NO', CODE_SIGN_STYLE='Automatic',
            CURRENT_PROJECT_VERSION='1', MARKETING_VERSION='0.1.0', ASSETCATALOG_COMPILER_APPICON_NAME='AppIcon',
            SWIFT_OPTIMIZATION_LEVEL='-Onone' if name == 'Debug' else '-O',
            DEBUG_INFORMATION_FORMAT='dwarf' if name == 'Debug' else 'dwarf-with-dsym',
            ENABLE_TESTABILITY='YES' if name == 'Debug' else 'NO',
            SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG' if name == 'Debug' else '',
            CLANG_ENABLE_MODULES='YES', LD_RUNPATH_SEARCH_PATHS=['$(inherited)', '@executable_path/Frameworks'])
        configs.append(add('app:' + name, isa='XCBuildConfiguration', buildSettings=settings, name=name))
        project_configs.append(add('project:' + name, isa='XCBuildConfiguration', buildSettings={'CLANG_ENABLE_MODULES': 'YES'}, name=name))
    app_configs = add('app-configs', isa='XCConfigurationList', buildConfigurations=configs, defaultConfigurationIsVisible=0, defaultConfigurationName='Release')
    project_config_list = add('project-configs', isa='XCConfigurationList', buildConfigurations=project_configs, defaultConfigurationIsVisible=0, defaultConfigurationName='Release')
    target = add('target', isa='PBXNativeTarget', buildConfigurationList=app_configs, buildPhases=[source_phase, frameworks, resources], buildRules=[], dependencies=[], name='ShabbatTV', productName='ShabbatTV', productReference=product, productType='com.apple.product-type.application')
    project = add('project', isa='PBXProject', attributes={'LastUpgradeCheck': '1600'}, buildConfigurationList=project_config_list, compatibilityVersion='Xcode 14.0', developmentRegion='fr', hasScannedForEncodings=0, knownRegions=['fr', 'en', 'Base'], mainGroup=group, productRefGroup=products, projectDirPath='', projectRoot='', targets=[target])
    def encode(value, depth=0):
        if isinstance(value, dict):
            return '{\n' + ''.join('  '*(depth+1) + json.dumps(k) + ' = ' + encode(v, depth+1) + ';\n' for k,v in value.items()) + '  '*depth + '}'
        if isinstance(value, list): return '(' + ', '.join(encode(v, depth) for v in value) + ')'
        return json.dumps(value)
    folder = ROOT / 'ShabbatTV.xcodeproj'; folder.mkdir(exist_ok=True)
    (folder / 'project.pbxproj').write_text('// !$*UTF8*$!\n' + encode(dict(archiveVersion=1, classes={}, objectVersion=56, objects=objects, rootObject=project)) + '\n', encoding='utf-8')
    scheme = folder / 'xcshareddata/xcschemes/ShabbatTV.xcscheme'; scheme.parent.mkdir(parents=True, exist_ok=True)
    reference = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="ShabbatTV.app" BlueprintName="ShabbatTV" ReferencedContainer="container:ShabbatTV.xcodeproj"/>'
    scheme.write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
 <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{reference}</BuildActionEntry></BuildActionEntries></BuildAction>
 <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables/></TestAction>
 <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></LaunchAction>
 <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></ProfileAction>
 <AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
''', encoding='utf-8')
    info = dict(CFBundleDevelopmentRegion='fr', CFBundleDisplayName='ShabbatTV', CFBundleExecutable='$(EXECUTABLE_NAME)',
        CFBundleIdentifier='$(PRODUCT_BUNDLE_IDENTIFIER)', CFBundleInfoDictionaryVersion='6.0', CFBundleName='ShabbatTV', CFBundlePackageType='APPL',
        CFBundleShortVersionString='$(MARKETING_VERSION)', CFBundleVersion='$(CURRENT_PROJECT_VERSION)', LSRequiresIPhoneOS=True,
        UILaunchScreen={}, UISupportedInterfaceOrientations=['UIInterfaceOrientationPortrait', 'UIInterfaceOrientationLandscapeLeft', 'UIInterfaceOrientationLandscapeRight'],
        UIApplicationSceneManifest={'UIApplicationSupportsMultipleScenes':False, 'UISceneConfigurations':{
            'UIWindowSceneSessionRoleApplication':[{'UISceneConfigurationName':'Main', 'UISceneDelegateClassName':'$(PRODUCT_MODULE_NAME).MainSceneDelegate'}],
            'UIWindowSceneSessionRoleExternalDisplayNonInteractive':[{'UISceneConfigurationName':'External', 'UISceneDelegateClassName':'$(PRODUCT_MODULE_NAME).ExternalSceneDelegate'}]}})
    (ROOT / 'ios/App/Info.plist').write_bytes(plistlib.dumps(info, sort_keys=True))
    print(f'Generated project with {len(sources)} Swift source files')
    return objects

if __name__ == '__main__': generate()
