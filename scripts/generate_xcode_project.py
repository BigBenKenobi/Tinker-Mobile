#!/usr/bin/env python3
"""Generate a dependency-free, deterministic Xcode iPhone app and XCTest project.

Run from any directory. The checked-in result opens directly in Xcode; this script
only regenerates source/resource references after files change. It creates no
signing identity or fabricated build acceptance and never downloads packages.
"""
from pathlib import Path
import hashlib

ROOT = Path(__file__).resolve().parents[1] / 'ios'
PROJECT = ROOT / 'TinkerCompanion.xcodeproj'
OBJECTS = []


def oid(name):
    """Stable 24-hex Xcode object identifiers independent of run order."""
    return hashlib.sha256(name.encode()).hexdigest()[:24].upper()


def obj(name, body):
    """Append an OpenStep object and return its stable ID for later references."""
    result=oid(name); OBJECTS.append(f'{result} = {{ {body} }};'); return result


def refs(items):
    """Encode one Xcode reference list; callers provide already defined IDs."""
    return '('+','.join(items)+',)' if items else '()'


def files(folder):
    """Recursively register Swift sources relative to their owning target group."""
    references=[]; builds=[]
    for path in sorted((ROOT/folder).rglob('*.swift')):
        ref=obj(str(path.relative_to(ROOT)),f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{path.relative_to(ROOT/folder).as_posix()}"; sourceTree = "<group>";')
        references.append(ref); builds.append(obj('build:'+str(path.relative_to(ROOT)),f'isa = PBXBuildFile; fileRef = {ref};'))
    group=obj(folder,f'isa = PBXGroup; children = {refs(references)}; path = "{folder}"; sourceTree = "<group>";')
    return group,builds


def configurations(name, settings):
    """Give both targets matching simulator/device settings with automatic signing."""
    ids=[]
    for config in ('Debug','Release'):
        additions='SWIFT_OPTIMIZATION_LEVEL = "-Onone"; ENABLE_TESTABILITY = YES;' if config=='Debug' else 'SWIFT_OPTIMIZATION_LEVEL = "-O";'
        ids.append(obj(name+config,f'isa = XCBuildConfiguration; buildSettings = {{ {settings} {additions} }}; name = {config};'))
    return obj(name+'configurations',f'isa = XCConfigurationList; buildConfigurations = {refs(ids)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')


app_group,app_builds=files('TinkerCompanion')
test_group,test_builds=files('TinkerCompanionTests')
ui_group,ui_builds=files('TinkerCompanionUITests')
# Asset catalogs are packaged by Xcode, not flattened into individual image references.
asset_refs=[]; asset_builds=[]
for path in sorted((ROOT/'TinkerCompanion').rglob('*.xcassets')):
    ref=obj(str(path.relative_to(ROOT)),f'isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = "{path.relative_to(ROOT).as_posix()}"; sourceTree = "<group>";')
    asset_refs.append(ref); asset_builds.append(obj('build:'+str(path.relative_to(ROOT)),f'isa = PBXBuildFile; fileRef = {ref};'))
fixture=obj('snapshot-fixture','isa = PBXFileReference; lastKnownFileType = text.json; name = "snapshot-v2.json"; path = "../contracts/snapshot-v2.json"; sourceTree = "<group>";')
fixture_build=obj('fixture-build',f'isa = PBXBuildFile; fileRef = {fixture};')
theme_fixture=obj('theme-fixture','isa = PBXFileReference; lastKnownFileType = text.json; name = "theme-v1.json"; path = "../contracts/theme-v1.json"; sourceTree = "<group>";')
theme_fixture_build=obj('theme-fixture-build',f'isa = PBXBuildFile; fileRef = {theme_fixture};')
app_product=obj('app-product','isa = PBXFileReference; explicitFileType = wrapper.application; path = TinkerCompanion.app; sourceTree = BUILT_PRODUCTS_DIR;')
test_product=obj('test-product','isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = TinkerCompanionTests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
ui_product=obj('ui-product','isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = TinkerCompanionUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
products=obj('products',f'isa = PBXGroup; children = {refs([app_product,test_product,ui_product])}; name = Products; sourceTree = "<group>";')
main=obj('main',f'isa = PBXGroup; children = {refs([app_group,test_group,ui_group,fixture,theme_fixture,products]+asset_refs)}; sourceTree = "<group>";')
common='IPHONEOS_DEPLOYMENT_TARGET = 17.0; SDKROOT = iphoneos; SWIFT_VERSION = 5.0; TARGETED_DEVICE_FAMILY = 1; CODE_SIGN_STYLE = Automatic; SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"; SUPPORTS_MACCATALYST = NO;'
app_configs=configurations('app',common+' PRODUCT_BUNDLE_IDENTIFIER = "com.bigbenkenobi.tinker-companion"; PRODUCT_NAME = "$(TARGET_NAME)"; INFOPLIST_FILE = TinkerCompanion/Info.plist; GENERATE_INFOPLIST_FILE = NO; OTHER_LDFLAGS = "$(inherited) -lsqlite3";')
test_configs=configurations('tests',common+' PRODUCT_BUNDLE_IDENTIFIER = "com.bigbenkenobi.tinker-companion.tests"; PRODUCT_NAME = "$(TARGET_NAME)"; GENERATE_INFOPLIST_FILE = YES; TEST_HOST = "$(BUILT_PRODUCTS_DIR)/TinkerCompanion.app/TinkerCompanion"; BUNDLE_LOADER = "$(TEST_HOST)";')
ui_configs=configurations('ui',common+' PRODUCT_BUNDLE_IDENTIFIER = "com.bigbenkenobi.tinker-companion.uitests"; PRODUCT_NAME = "$(TARGET_NAME)"; GENERATE_INFOPLIST_FILE = YES; TEST_TARGET_NAME = TinkerCompanion;')
project_configs=configurations('project','CLANG_ENABLE_MODULES = YES; SWIFT_VERSION = 5.0; IPHONEOS_DEPLOYMENT_TARGET = 17.0;')
for name,builds in (('app',app_builds),('tests',test_builds),('ui',ui_builds)):
    obj(name+'sources',f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = {refs(builds)}; runOnlyForDeploymentPostprocessing = 0;')
    obj(name+'frameworks','isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
    obj(name+'resources',f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = {refs([fixture_build,theme_fixture_build] if name=="tests" else asset_builds if name=="app" else [])}; runOnlyForDeploymentPostprocessing = 0;')
proxy=obj('proxy',f'isa = PBXContainerItemProxy; containerPortal = {oid("project")}; proxyType = 1; remoteGlobalIDString = {oid("app-target")}; remoteInfo = TinkerCompanion;')
dependency=obj('dependency',f'isa = PBXTargetDependency; target = {oid("app-target")}; targetProxy = {proxy};')
for name,product,configs,title,product_type in (('app',app_product,app_configs,'TinkerCompanion','com.apple.product-type.application'),('tests',test_product,test_configs,'TinkerCompanionTests','com.apple.product-type.bundle.unit-test'),('ui',ui_product,ui_configs,'TinkerCompanionUITests','com.apple.product-type.bundle.ui-testing')):
    obj(name+'-target',f'isa = PBXNativeTarget; buildConfigurationList = {configs}; buildPhases = {refs([oid(name+"sources"),oid(name+"frameworks"),oid(name+"resources")])}; buildRules = (); dependencies = {refs([dependency] if name in ("tests","ui") else [])}; name = {title}; productName = {title}; productReference = {product}; productType = "{product_type}";')
obj('project',f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 1600; }}; buildConfigurationList = {project_configs}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en,Base); mainGroup = {main}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = {refs([oid("app-target"),oid("tests-target"),oid("ui-target")])};')
PROJECT.mkdir(parents=True,exist_ok=True)
(PROJECT/'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(OBJECTS)+f'\n}}; rootObject = {oid("project")}; }}\n')
schemes=PROJECT/'xcshareddata/xcschemes'; schemes.mkdir(parents=True,exist_ok=True)
def buildable(target):
    """Emit the scheme reference for a named target using the same stable identifiers."""
    name={'app':'TinkerCompanion','tests':'TinkerCompanionTests','ui':'TinkerCompanionUITests'}[target]
    return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{oid(target+"-target")}" BuildableName="{name}.{"app" if target=="app" else "xctest"}" BlueprintName="{name}" ReferencedContainer="container:TinkerCompanion.xcodeproj"/>'
(schemes/'TinkerCompanion.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.7">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{buildable('app')}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{buildable('tests')}</TestableReference><TestableReference skipped="NO">{buildable('ui')}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{buildable('app')}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO"><BuildableProductRunnable runnableDebuggingMode="0">{buildable('app')}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
print(PROJECT)
