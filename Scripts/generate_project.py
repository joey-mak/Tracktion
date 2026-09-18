"""Generate a dependency-free, reproducible Xcode project using only Python stdlib."""
from pathlib import Path
import hashlib, plistlib
ROOT = Path(__file__).resolve().parent.parent
objects = {}
def ident(s): return hashlib.sha1(s.encode()).hexdigest()[:24].upper()
def obj(key, text):
    uid = ident(key); objects[uid] = text; return uid
def arr(xs): return '(' + ','.join(xs) + ',)'
def configs(name, extra):
    ids=[]
    for mode in ['Debug','Release']:
        settings = {'SDKROOT':'iphoneos','IPHONEOS_DEPLOYMENT_TARGET':'17.0','SWIFT_VERSION':'5.0','CLANG_ENABLE_MODULES':'YES','SWIFT_OPTIMIZATION_LEVEL':'-Onone' if mode=='Debug' else '-O','DEBUG_INFORMATION_FORMAT':'dwarf','TARGETED_DEVICE_FAMILY':'1','CODE_SIGN_STYLE':'Automatic',**extra}
        if mode=='Debug': settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS']='DEBUG'
        body=' '.join(f'{k} = "{v}";' for k,v in settings.items())
        ids.append(obj(name+mode,f'{{isa = XCBuildConfiguration; name = {mode}; buildSettings = {{{body}}};}}'))
    return obj(name+'configs',f'{{isa = XCConfigurationList; buildConfigurations = {arr(ids)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;}}')
refs={}
for p in sorted((ROOT/'Sources').rglob('*.swift')):
    path=p.relative_to(ROOT).as_posix()
    refs[path]=obj(path,f'{{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{path}"; sourceTree = SOURCE_ROOT;}}')
assets=obj('assets','{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Resources/Assets.xcassets; sourceTree = SOURCE_ROOT;}')
circuits=obj('circuits','{isa = PBXFileReference; lastKnownFileType = folder; path = Resources/Circuits; sourceTree = SOURCE_ROOT;}')
locales=[]
for lang in ['en','zh-Hans']:
    locales.append(obj('locale'+lang,f'{{isa = PBXFileReference; lastKnownFileType = text.plist.strings; name = "{lang}"; path = "Resources/{lang}.lproj/InfoPlist.strings"; sourceTree = SOURCE_ROOT;}}'))
localizedInfo=obj('localizedInfo',f'{{isa = PBXVariantGroup; children = {arr(locales)}; name = InfoPlist.strings; sourceTree = "<group>";}}')
appProd=obj('appProduct','{isa = PBXFileReference; explicitFileType = wrapper.application; path = RaceWeek.app; sourceTree = BUILT_PRODUCTS_DIR;}')
widgetProd=obj('widgetProduct','{isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; path = RaceWeekWidgets.appex; sourceTree = BUILT_PRODUCTS_DIR;}')
products=obj('products',f'{{isa = PBXGroup; name = Products; children = {arr([appProd,widgetProd])}; sourceTree = "<group>";}}')
group=obj('rootGroup',f'{{isa = PBXGroup; children = {arr(list(refs.values())+[assets,circuits,localizedInfo,products])}; sourceTree = "<group>";}}')
targets=[]
for name,widget in [('RaceWeekWidgets',True),('RaceWeek',False)]:
    build=[]
    for path,ref in refs.items():
        if ('/App/' in path and widget) or ('/Widget/' in path and not widget): continue
        build.append(obj(name+path,f'{{isa = PBXBuildFile; fileRef = {ref};}}'))
    sources=obj(name+'sources',f'{{isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = {arr(build)}; runOnlyForDeploymentPostprocessing = 0;}}')
    resourceRefs=[localizedInfo] if widget else [assets,circuits,localizedInfo]
    resourceBuilds=[obj(name+'resource'+ref,f'{{isa = PBXBuildFile; fileRef = {ref};}}') for ref in resourceRefs]
    resources=obj(name+'resources',f'{{isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = {arr(resourceBuilds)}; runOnlyForDeploymentPostprocessing = 0;}}')
    phases=[sources,resources]; deps=[]
    if not widget:
        embed=obj('embedBuild',f'{{isa = PBXBuildFile; fileRef = {widgetProd}; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy,);}};}}')
        phases.append(obj('embed',f'{{isa = PBXCopyFilesBuildPhase; buildActionMask = 2147483647; dstPath = ""; dstSubfolderSpec = 13; files = ({embed},); name = "Embed App Extensions"; runOnlyForDeploymentPostprocessing = 0;}}'))
        proxy=obj('proxy',f'{{isa = PBXContainerItemProxy; containerPortal = {ident("project")}; proxyType = 1; remoteGlobalIDString = {ident("RaceWeekWidgetsTarget")}; remoteInfo = RaceWeekWidgets;}}')
        deps=[obj('dependency',f'{{isa = PBXTargetDependency; target = {ident("RaceWeekWidgetsTarget")}; targetProxy = {proxy};}}')]
    extra={'PRODUCT_BUNDLE_IDENTIFIER':'app.raceweek.personal'+('.widgets' if widget else ''),'PRODUCT_NAME':name,'INFOPLIST_FILE':'Resources/'+('Widget' if widget else 'App')+'Info.plist','CODE_SIGN_ENTITLEMENTS':'Resources/Shared.entitlements','CURRENT_PROJECT_VERSION':'1','MARKETING_VERSION':'0.1.0','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/Frameworks'+(' @executable_path/../../Frameworks' if widget else ''),'GENERATE_INFOPLIST_FILE':'NO','SKIP_INSTALL':'YES' if widget else 'NO'}
    if widget: extra['APPLICATION_EXTENSION_API_ONLY']='YES'
    else: extra['ASSETCATALOG_COMPILER_APPICON_NAME']='AppIcon'
    extra['CURRENT_PROJECT_VERSION']='2'
    extra['MARKETING_VERSION']='0.2.0'
    conf=configs(name,extra)
    product=widgetProd if widget else appProd
    typ='app-extension' if widget else 'application'
    targets.append(obj(name+'Target',f'{{isa = PBXNativeTarget; buildConfigurationList = {conf}; buildPhases = {arr(phases)}; buildRules = (); dependencies = {arr(deps) if deps else "()"}; name = {name}; productName = {name}; productReference = {product}; productType = "com.apple.product-type.{typ}";}}'))
project=obj('project',f'{{isa = PBXProject; attributes = {{LastUpgradeCheck = 2630; BuildIndependentTargetsInParallel = YES;}}; buildConfigurationList = {configs("project",{})}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; knownRegions = (en,"zh-Hans",Base,); mainGroup = {group}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = {arr(targets)};}}')
out=ROOT/'RaceWeek.xcodeproj';out.mkdir(exist_ok=True)
(out/'project.pbxproj').write_text('// !$*UTF8*$!\n{archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(f'{k} = {v};' for k,v in objects.items())+f'\n}}; rootObject = {project};}}\n')
common={'CFBundleDevelopmentRegion':'en','CFBundleExecutable':'$(EXECUTABLE_NAME)','CFBundleIdentifier':'$(PRODUCT_BUNDLE_IDENTIFIER)','CFBundleInfoDictionaryVersion':'6.0','CFBundleName':'$(PRODUCT_NAME)','CFBundleShortVersionString':'$(MARKETING_VERSION)','CFBundleVersion':'$(CURRENT_PROJECT_VERSION)'}
app={**common,'CFBundleDisplayName':'Tracktion','CFBundlePackageType':'APPL','LSRequiresIPhoneOS':True,'UILaunchScreen':{},'UIApplicationSceneManifest':{'UIApplicationSupportsMultipleScenes':False},'UISupportedInterfaceOrientations':['UIInterfaceOrientationPortrait'],'CFBundleURLTypes':[{'CFBundleURLName':'app.raceweek.personal','CFBundleURLSchemes':['raceweek','tracktion']}]}
widget={**common,'CFBundleDisplayName':'Tracktion Widgets','CFBundlePackageType':'XPC!','NSExtension':{'NSExtensionPointIdentifier':'com.apple.widgetkit-extension'}}
for name,value in [('AppInfo.plist',app),('WidgetInfo.plist',widget),('Shared.entitlements',{'com.apple.security.application-groups':['group.app.raceweek.personal']})]:
    (ROOT/'Resources'/name).write_bytes(plistlib.dumps(value))
scheme=f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2630" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ident('RaceWeekTarget')}" BuildableName="RaceWeek.app" BlueprintName="RaceWeek" ReferencedContainer="container:RaceWeek.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ident('RaceWeekTarget')}" BuildableName="RaceWeek.app" BlueprintName="RaceWeek" ReferencedContainer="container:RaceWeek.xcodeproj"/></BuildableProductRunnable></LaunchAction><ProfileAction buildConfiguration="Release"/><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>'''
schemeDir=out/'xcshareddata/xcschemes';schemeDir.mkdir(parents=True,exist_ok=True)
(schemeDir/'RaceWeek.xcscheme').write_text(scheme)
print('Generated RaceWeek.xcodeproj')
