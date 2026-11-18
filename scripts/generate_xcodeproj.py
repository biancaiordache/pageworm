#!/usr/bin/env python3
"""Writes Pageworm.xcodeproj. Re-run only if targets are added."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJ = ROOT / "Pageworm.xcodeproj"
PROJ.mkdir(exist_ok=True)

def bid(n: int) -> str:
    return f"A1{n:022d}"

# Stable ids
PROJECT = bid(1)
MAIN_GROUP = bid(2)
PRODUCTS = bid(3)
CONFIG_GROUP = bid(4)

APP = bid(10)
SHIELD_CFG = bid(11)
SHIELD_ACT = bid(12)
MONITOR = bid(13)
REPORT = bid(14)
WIDGET = bid(15)

SYNC_APP = bid(20)
SYNC_SHARED = bid(21)
SYNC_SCREENTIME = bid(22)
SYNC_SHIELD_CFG = bid(23)
SYNC_SHIELD_ACT = bid(24)
SYNC_MONITOR = bid(25)
SYNC_REPORT = bid(26)
SYNC_WIDGET = bid(27)

PROD_APP = bid(30)
PROD_SHIELD_CFG = bid(31)
PROD_SHIELD_ACT = bid(32)
PROD_MONITOR = bid(33)
PROD_REPORT = bid(34)
PROD_WIDGET = bid(35)

SRC_APP = bid(40)
SRC_SHIELD_CFG = bid(41)
SRC_SHIELD_ACT = bid(42)
SRC_MONITOR = bid(43)
SRC_REPORT = bid(44)
SRC_WIDGET = bid(45)

FW_APP = bid(50)
FW_SHIELD_CFG = bid(51)
FW_SHIELD_ACT = bid(52)
FW_MONITOR = bid(53)
FW_REPORT = bid(54)
FW_WIDGET = bid(55)

RES_APP = bid(60)
RES_SHIELD_CFG = bid(61)
RES_SHIELD_ACT = bid(62)
RES_MONITOR = bid(63)
RES_REPORT = bid(64)
RES_WIDGET = bid(65)

EMBED = bid(70)

LOCAL_PKG = bid(80)
REMOTE_PKG = bid(81)
DEP_CORE = bid(82)
DEP_RC = bid(83)
BF_CORE_APP = bid(84)
BF_RC_APP = bid(85)
BF_CORE_SHIELD_CFG = bid(86)
BF_CORE_SHIELD_ACT = bid(87)
BF_CORE_MONITOR = bid(88)
BF_CORE_REPORT = bid(89)
BF_CORE_WIDGET = bid(90)

CFG_LIST_PROJECT = bid(100)
CFG_LIST_APP = bid(101)
CFG_LIST_SHIELD_CFG = bid(102)
CFG_LIST_SHIELD_ACT = bid(103)
CFG_LIST_MONITOR = bid(104)
CFG_LIST_REPORT = bid(105)
CFG_LIST_WIDGET = bid(106)

CFG_P_DBG = bid(110)
CFG_P_REL = bid(111)
CFG_APP_DBG = bid(112)
CFG_APP_REL = bid(113)
CFG_SC_DBG = bid(114)
CFG_SC_REL = bid(115)
CFG_SA_DBG = bid(116)
CFG_SA_REL = bid(117)
CFG_MO_DBG = bid(118)
CFG_MO_REL = bid(119)
CFG_RE_DBG = bid(120)
CFG_RE_REL = bid(121)
CFG_WI_DBG = bid(122)
CFG_WI_REL = bid(123)

extensions = [
    ("ShieldConfiguration", SHIELD_CFG, PROD_SHIELD_CFG, "PagewormShieldConfiguration.appex", bid(130), bid(140)),
    ("ShieldAction", SHIELD_ACT, PROD_SHIELD_ACT, "PagewormShieldAction.appex", bid(131), bid(141)),
    ("DeviceActivityMonitor", MONITOR, PROD_MONITOR, "PagewormDeviceActivityMonitor.appex", bid(132), bid(142)),
    ("DeviceActivityReport", REPORT, PROD_REPORT, "PagewormDeviceActivityReport.appex", bid(133), bid(143)),
    ("Widgets", WIDGET, PROD_WIDGET, "PagewormWidgets.appex", bid(134), bid(144)),
]

config_files = [
    (bid(150), "Pageworm.entitlements", "Config/Entitlements/Pageworm.entitlements"),
    (bid(151), "Widget.entitlements", "Config/Entitlements/Widget.entitlements"),
    (bid(152), "Pageworm-Info.plist", "Config/Info/Pageworm-Info.plist"),
    (bid(153), "ShieldConfiguration-Info.plist", "Config/Info/ShieldConfiguration-Info.plist"),
    (bid(154), "ShieldAction-Info.plist", "Config/Info/ShieldAction-Info.plist"),
    (bid(155), "DeviceActivityMonitor-Info.plist", "Config/Info/DeviceActivityMonitor-Info.plist"),
    (bid(156), "DeviceActivityReport-Info.plist", "Config/Info/DeviceActivityReport-Info.plist"),
    (bid(157), "Widgets-Info.plist", "Config/Info/Widgets-Info.plist"),
]

project_common = """
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				COPY_PHASE_STRIP = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				LOCALIZATION_PREFERS_STRING_CATALOGS = YES;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				MTL_FAST_MATH = YES;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SDKROOT = iphoneos;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = 1;
"""

debug_extra = """
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_TESTABILITY = YES;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_OPTIMIZATION_LEVEL = 0;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				ONLY_ACTIVE_ARCH = YES;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
"""

release_extra = """
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				MTL_ENABLE_DEBUG_INFO = NO;
				SWIFT_COMPILATION_MODE = wholemodule;
				SWIFT_OPTIMIZATION_LEVEL = "-O";
				VALIDATE_PRODUCT = YES;
"""

def target_base(bundle, info, entitlements, module, extension=False):
    lines = f"""
				CODE_SIGN_ENTITLEMENTS = "{entitlements}";
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_FILE = "{info}";
				INFOPLIST_KEY_CFBundleDisplayName = Pageworm;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
					"@executable_path/../../Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = {bundle};
				PRODUCT_MODULE_NAME = {module};
				SKIP_INSTALL = {"YES" if extension else "NO"};
				TARGETED_DEVICE_FAMILY = 1;
"""
    if extension:
        lines += "\t\t\t\tAPPLICATION_EXTENSION_API_ONLY = YES;\n"
    else:
        lines += """
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				ENABLE_PREVIEWS = YES;
				INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO;
				INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.lifestyle";
				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait;
				SUPPORTS_MACCATALYST = NO;
"""
    return lines

targets = {
    "app": target_base(
        "com.pageworm.app",
        "Config/Info/Pageworm-Info.plist",
        "Config/Entitlements/Pageworm.entitlements",
        "Pageworm",
        False,
    ),
    "shieldcfg": target_base(
        "com.pageworm.app.ShieldConfiguration",
        "Config/Info/ShieldConfiguration-Info.plist",
        "Config/Entitlements/Pageworm.entitlements",
        "PagewormShieldConfiguration",
        True,
    ),
    "shieldact": target_base(
        "com.pageworm.app.ShieldAction",
        "Config/Info/ShieldAction-Info.plist",
        "Config/Entitlements/Pageworm.entitlements",
        "PagewormShieldAction",
        True,
    ),
    "monitor": target_base(
        "com.pageworm.app.DeviceActivityMonitor",
        "Config/Info/DeviceActivityMonitor-Info.plist",
        "Config/Entitlements/Pageworm.entitlements",
        "PagewormDeviceActivityMonitor",
        True,
    ),
    "report": target_base(
        "com.pageworm.app.DeviceActivityReport",
        "Config/Info/DeviceActivityReport-Info.plist",
        "Config/Entitlements/Pageworm.entitlements",
        "PagewormDeviceActivityReport",
        True,
    ),
    "widget": target_base(
        "com.pageworm.app.Widgets",
        "Config/Info/Widgets-Info.plist",
        "Config/Entitlements/Widget.entitlements",
        "PagewormWidgets",
        True,
    ),
}

def config_block(cid, name, settings):
    return f"""\t\t{cid} /* {name} */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{{settings}
			}};
			name = {name};
		}};"""

parts = []
parts.append("""// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 70;
	objects = {

/* Begin PBXBuildFile section */""")

build_files = [
    (BF_CORE_APP, DEP_CORE, "PagewormCore in Frameworks"),
    (BF_RC_APP, DEP_RC, "RevenueCat in Frameworks"),
    (BF_CORE_SHIELD_CFG, DEP_CORE, "PagewormCore in Frameworks"),
    (BF_CORE_SHIELD_ACT, DEP_CORE, "PagewormCore in Frameworks"),
    (BF_CORE_MONITOR, DEP_CORE, "PagewormCore in Frameworks"),
    (BF_CORE_REPORT, DEP_CORE, "PagewormCore in Frameworks"),
    (BF_CORE_WIDGET, DEP_CORE, "PagewormCore in Frameworks"),
]
for bf, dep, name in build_files:
    # productRef build files don't repeat the same dep id as unique objects; each build file is unique
    parts.append(f"\t\t{bf} /* {name} */ = {{isa = PBXBuildFile; productRef = {dep} /* {name.split(' in ')[0]} */; }};")

for name, target, prod, path, proxy, embed_bf in extensions:
    parts.append(
        f"\t\t{embed_bf} /* {path} in Embed Foundation Extensions */ = {{isa = PBXBuildFile; fileRef = {prod} /* {path} */; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};"
    )

parts.append("/* End PBXBuildFile section */\n")

parts.append("/* Begin PBXContainerItemProxy section */")
for name, target, prod, path, proxy, embed_bf in extensions:
    parts.append(f"""\t\t{proxy} /* PBXContainerItemProxy */ = {{
			isa = PBXContainerItemProxy;
			containerPortal = {PROJECT} /* Project object */;
			proxyType = 1;
			remoteGlobalIDString = {target};
			remoteInfo = Pageworm{name if name != "Widgets" else "Widgets"};
		}};""")
parts.append("/* End PBXContainerItemProxy section */\n")

parts.append("/* Begin PBXCopyFilesBuildPhase section */")
embed_list = "\n".join(f"\t\t\t\t{embed_bf} /* {path} in Embed Foundation Extensions */," for _, _, _, path, _, embed_bf in extensions)
parts.append(f"""\t\t{EMBED} /* Embed Foundation Extensions */ = {{
			isa = PBXCopyFilesBuildPhase;
			buildActionMask = 2147483647;
			dstPath = "";
			dstSubfolderSpec = 13;
			files = (
{embed_list}
			);
			name = "Embed Foundation Extensions";
			runOnlyForDeploymentPostprocessing = 0;
		}};""")
parts.append("/* End PBXCopyFilesBuildPhase section */\n")

parts.append("/* Begin PBXFileReference section */")
products = [
    (PROD_APP, "wrapper.application", "Pageworm.app"),
    (PROD_SHIELD_CFG, "wrapper.app-extension", "PagewormShieldConfiguration.appex"),
    (PROD_SHIELD_ACT, "wrapper.app-extension", "PagewormShieldAction.appex"),
    (PROD_MONITOR, "wrapper.app-extension", "PagewormDeviceActivityMonitor.appex"),
    (PROD_REPORT, "wrapper.app-extension", "PagewormDeviceActivityReport.appex"),
    (PROD_WIDGET, "wrapper.app-extension", "PagewormWidgets.appex"),
]
for pid, ftype, path in products:
    parts.append(f'\t\t{pid} /* {path} */ = {{isa = PBXFileReference; explicitFileType = "{ftype}"; includeInIndex = 0; path = {path}; sourceTree = BUILT_PRODUCTS_DIR; }};')
for fid, name, path in config_files:
    parts.append(f'\t\t{fid} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = "{path}"; sourceTree = "<group>"; }};')
parts.append("/* End PBXFileReference section */\n")

parts.append("/* Begin PBXFileSystemSynchronizedRootGroup section */")
syncs = [
    (SYNC_APP, "Pageworm"),
    (SYNC_SHARED, "Shared"),
    (SYNC_SCREENTIME, "ScreenTimeShared"),
    (SYNC_SHIELD_CFG, "Extensions/ShieldConfiguration"),
    (SYNC_SHIELD_ACT, "Extensions/ShieldAction"),
    (SYNC_MONITOR, "Extensions/DeviceActivityMonitor"),
    (SYNC_REPORT, "Extensions/DeviceActivityReport"),
    (SYNC_WIDGET, "Extensions/Widgets"),
]
for sid, path in syncs:
    parts.append(f"""\t\t{sid} /* {path} */ = {{
			isa = PBXFileSystemSynchronizedRootGroup;
			path = "{path}";
			sourceTree = "<group>";
		}};""")
parts.append("/* End PBXFileSystemSynchronizedRootGroup section */\n")

def phase(kind, pid, files):
    body = "\n".join(f"\t\t\t\t{f}," for f in files)
    return f"""\t\t{pid} /* {kind} */ = {{
			isa = PBX{kind}BuildPhase;
			buildActionMask = 2147483647;
			files = (
{body}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};"""

parts.append("/* Begin PBXFrameworksBuildPhase section */")
parts.append(phase("Frameworks", FW_APP, [f"{BF_CORE_APP} /* PagewormCore in Frameworks */", f"{BF_RC_APP} /* RevenueCat in Frameworks */"]))
parts.append(phase("Frameworks", FW_SHIELD_CFG, [f"{BF_CORE_SHIELD_CFG} /* PagewormCore in Frameworks */"]))
parts.append(phase("Frameworks", FW_SHIELD_ACT, [f"{BF_CORE_SHIELD_ACT} /* PagewormCore in Frameworks */"]))
parts.append(phase("Frameworks", FW_MONITOR, [f"{BF_CORE_MONITOR} /* PagewormCore in Frameworks */"]))
parts.append(phase("Frameworks", FW_REPORT, [f"{BF_CORE_REPORT} /* PagewormCore in Frameworks */"]))
parts.append(phase("Frameworks", FW_WIDGET, [f"{BF_CORE_WIDGET} /* PagewormCore in Frameworks */"]))
parts.append("/* End PBXFrameworksBuildPhase section */\n")

parts.append("/* Begin PBXGroup section */")
sync_children = "\n".join(f"\t\t\t\t{sid} /* {path} */," for sid, path in syncs)
config_children = "\n".join(f'\t\t\t\t{fid} /* {name} */,' for fid, name, _ in config_files)
product_children = "\n".join(f"\t\t\t\t{pid} /* {path} */," for pid, _, path in products)
parts.append(f"""\t\t{MAIN_GROUP} = {{
			isa = PBXGroup;
			children = (
{sync_children}
				{CONFIG_GROUP} /* Config */,
				{PRODUCTS} /* Products */,
			);
			sourceTree = "<group>";
		}};
		{CONFIG_GROUP} /* Config */ = {{
			isa = PBXGroup;
			children = (
{config_children}
			);
			name = Config;
			sourceTree = "<group>";
		}};
		{PRODUCTS} /* Products */ = {{
			isa = PBXGroup;
			children = (
{product_children}
			);
			name = Products;
			sourceTree = "<group>";
		}};""")
parts.append("/* End PBXGroup section */\n")

parts.append("/* Begin PBXNativeTarget section */")

def native(tid, name, product_type, prod, phases, deps, packages, sync_groups):
    phase_body = "\n".join(f"\t\t\t\t{p}," for p in phases)
    dep_body = "\n".join(f"\t\t\t\t{d}," for d in deps)
    pkg_body = "\n".join(f"\t\t\t\t{p}," for p in packages)
    sync_body = "\n".join(f"\t\t\t\t{s}," for s in sync_groups)
    return f"""\t\t{tid} /* {name} */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = { {
                APP: CFG_LIST_APP,
                SHIELD_CFG: CFG_LIST_SHIELD_CFG,
                SHIELD_ACT: CFG_LIST_SHIELD_ACT,
                MONITOR: CFG_LIST_MONITOR,
                REPORT: CFG_LIST_REPORT,
                WIDGET: CFG_LIST_WIDGET,
            }[tid] } /* Build configuration list for PBXNativeTarget "{name}" */;
			buildPhases = (
{phase_body}
			);
			buildRules = (
			);
			dependencies = (
{dep_body}
			);
			fileSystemSynchronizedGroups = (
{sync_body}
			);
			name = {name};
			packageProductDependencies = (
{pkg_body}
			);
			productName = {name};
			productReference = {prod} /* {name} */;
			productType = "{product_type}";
		}};"""

app_deps = [bid(160 + i) for i in range(5)]
parts.append(native(
    APP, "Pageworm", "com.apple.product-type.application", PROD_APP,
    [SRC_APP, FW_APP, RES_APP, EMBED],
    app_deps,
    [DEP_CORE, DEP_RC],
    [SYNC_APP, SYNC_SHARED, SYNC_SCREENTIME],
))
parts.append(native(SHIELD_CFG, "PagewormShieldConfiguration", "com.apple.product-type.app-extension", PROD_SHIELD_CFG, [SRC_SHIELD_CFG, FW_SHIELD_CFG, RES_SHIELD_CFG], [], [DEP_CORE], [SYNC_SHIELD_CFG]))
parts.append(native(SHIELD_ACT, "PagewormShieldAction", "com.apple.product-type.app-extension", PROD_SHIELD_ACT, [SRC_SHIELD_ACT, FW_SHIELD_ACT, RES_SHIELD_ACT], [], [DEP_CORE], [SYNC_SHIELD_ACT]))
parts.append(native(MONITOR, "PagewormDeviceActivityMonitor", "com.apple.product-type.app-extension", PROD_MONITOR, [SRC_MONITOR, FW_MONITOR, RES_MONITOR], [], [DEP_CORE], [SYNC_MONITOR, SYNC_SCREENTIME]))
parts.append(native(REPORT, "PagewormDeviceActivityReport", "com.apple.product-type.app-extension", PROD_REPORT, [SRC_REPORT, FW_REPORT, RES_REPORT], [], [DEP_CORE], [SYNC_REPORT, SYNC_SHARED]))
parts.append(native(WIDGET, "PagewormWidgets", "com.apple.product-type.app-extension", PROD_WIDGET, [SRC_WIDGET, FW_WIDGET, RES_WIDGET], [], [DEP_CORE], [SYNC_WIDGET, SYNC_SHARED]))
parts.append("/* End PBXNativeTarget section */\n")

parts.append("/* Begin PBXProject section */")
parts.append(f"""\t\t{PROJECT} /* Project object */ = {{
			isa = PBXProject;
			attributes = {{
				BuildIndependentTargetsInParallel = 1;
				LastUpgradeCheck = 1600;
				TargetAttributes = {{
					{APP} = {{ CreatedOnToolsVersion = 16.0; }};
					{SHIELD_CFG} = {{ CreatedOnToolsVersion = 16.0; }};
					{SHIELD_ACT} = {{ CreatedOnToolsVersion = 16.0; }};
					{MONITOR} = {{ CreatedOnToolsVersion = 16.0; }};
					{REPORT} = {{ CreatedOnToolsVersion = 16.0; }};
					{WIDGET} = {{ CreatedOnToolsVersion = 16.0; }};
				}};
			}};
			buildConfigurationList = {CFG_LIST_PROJECT} /* Build configuration list for PBXProject "Pageworm" */;
			compatibilityVersion = "Xcode 15.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = {MAIN_GROUP};
			minimizedProjectReferenceProxies = 1;
			packageReferences = (
				{LOCAL_PKG} /* XCLocalSwiftPackageReference "Packages/PagewormCore" */,
				{REMOTE_PKG} /* XCRemoteSwiftPackageReference "purchases-ios-spm" */,
			);
			preferredProjectObjectVersion = 70;
			productRefGroup = {PRODUCTS} /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				{APP} /* Pageworm */,
				{SHIELD_CFG} /* PagewormShieldConfiguration */,
				{SHIELD_ACT} /* PagewormShieldAction */,
				{MONITOR} /* PagewormDeviceActivityMonitor */,
				{REPORT} /* PagewormDeviceActivityReport */,
				{WIDGET} /* PagewormWidgets */,
			);
		}};""")
parts.append("/* End PBXProject section */\n")

parts.append("/* Begin PBXResourcesBuildPhase section */")
for rid in (RES_APP, RES_SHIELD_CFG, RES_SHIELD_ACT, RES_MONITOR, RES_REPORT, RES_WIDGET):
    parts.append(phase("Resources", rid, []))
parts.append("/* End PBXResourcesBuildPhase section */\n")

parts.append("/* Begin PBXSourcesBuildPhase section */")
for sid in (SRC_APP, SRC_SHIELD_CFG, SRC_SHIELD_ACT, SRC_MONITOR, SRC_REPORT, SRC_WIDGET):
    parts.append(phase("Sources", sid, []))
parts.append("/* End PBXSourcesBuildPhase section */\n")

parts.append("/* Begin PBXTargetDependency section */")
for i, (name, target, prod, path, proxy, embed_bf) in enumerate(extensions):
    parts.append(f"""\t\t{app_deps[i]} /* PBXTargetDependency */ = {{
			isa = PBXTargetDependency;
			target = {target} /* Pageworm{name if name != "Widgets" else "Widgets"} */;
			targetProxy = {proxy} /* PBXContainerItemProxy */;
		}};""")
parts.append("/* End PBXTargetDependency section */\n")

parts.append("/* Begin XCBuildConfiguration section */")
parts.append(config_block(CFG_P_DBG, "Debug", project_common + debug_extra))
parts.append(config_block(CFG_P_REL, "Release", project_common + release_extra))
mapping = [
    (CFG_APP_DBG, "Debug", targets["app"] + debug_extra),
    (CFG_APP_REL, "Release", targets["app"] + release_extra),
    (CFG_SC_DBG, "Debug", targets["shieldcfg"] + debug_extra),
    (CFG_SC_REL, "Release", targets["shieldcfg"] + release_extra),
    (CFG_SA_DBG, "Debug", targets["shieldact"] + debug_extra),
    (CFG_SA_REL, "Release", targets["shieldact"] + release_extra),
    (CFG_MO_DBG, "Debug", targets["monitor"] + debug_extra),
    (CFG_MO_REL, "Release", targets["monitor"] + release_extra),
    (CFG_RE_DBG, "Debug", targets["report"] + debug_extra),
    (CFG_RE_REL, "Release", targets["report"] + release_extra),
    (CFG_WI_DBG, "Debug", targets["widget"] + debug_extra),
    (CFG_WI_REL, "Release", targets["widget"] + release_extra),
]
for cid, name, settings in mapping:
    parts.append(config_block(cid, name, settings))
parts.append("/* End XCBuildConfiguration section */\n")

def cfg_list(lid, debug, release, comment):
    return f"""\t\t{lid} /* {comment} */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{debug} /* Debug */,
				{release} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};"""

parts.append("/* Begin XCConfigurationList section */")
parts.append(cfg_list(CFG_LIST_PROJECT, CFG_P_DBG, CFG_P_REL, 'Build configuration list for PBXProject "Pageworm"'))
parts.append(cfg_list(CFG_LIST_APP, CFG_APP_DBG, CFG_APP_REL, 'Build configuration list for PBXNativeTarget "Pageworm"'))
parts.append(cfg_list(CFG_LIST_SHIELD_CFG, CFG_SC_DBG, CFG_SC_REL, 'Build configuration list for PBXNativeTarget "PagewormShieldConfiguration"'))
parts.append(cfg_list(CFG_LIST_SHIELD_ACT, CFG_SA_DBG, CFG_SA_REL, 'Build configuration list for PBXNativeTarget "PagewormShieldAction"'))
parts.append(cfg_list(CFG_LIST_MONITOR, CFG_MO_DBG, CFG_MO_REL, 'Build configuration list for PBXNativeTarget "PagewormDeviceActivityMonitor"'))
parts.append(cfg_list(CFG_LIST_REPORT, CFG_RE_DBG, CFG_RE_REL, 'Build configuration list for PBXNativeTarget "PagewormDeviceActivityReport"'))
parts.append(cfg_list(CFG_LIST_WIDGET, CFG_WI_DBG, CFG_WI_REL, 'Build configuration list for PBXNativeTarget "PagewormWidgets"'))
parts.append("/* End XCConfigurationList section */\n")

parts.append("/* Begin XCLocalSwiftPackageReference section */")
parts.append(f"""\t\t{LOCAL_PKG} /* XCLocalSwiftPackageReference "Packages/PagewormCore" */ = {{
			isa = XCLocalSwiftPackageReference;
			relativePath = Packages/PagewormCore;
		}};""")
parts.append("/* End XCLocalSwiftPackageReference section */\n")

parts.append("/* Begin XCRemoteSwiftPackageReference section */")
parts.append(f"""\t\t{REMOTE_PKG} /* XCRemoteSwiftPackageReference "purchases-ios-spm" */ = {{
			isa = XCRemoteSwiftPackageReference;
			repositoryURL = "https://github.com/RevenueCat/purchases-ios-spm.git";
			requirement = {{
				kind = upToNextMajorVersion;
				minimumVersion = 5.0.0;
			}};
		}};""")
parts.append("/* End XCRemoteSwiftPackageReference section */\n")

parts.append("/* Begin XCSwiftPackageProductDependency section */")
parts.append(f"""\t\t{DEP_CORE} /* PagewormCore */ = {{
			isa = XCSwiftPackageProductDependency;
			package = {LOCAL_PKG} /* XCLocalSwiftPackageReference "Packages/PagewormCore" */;
			productName = PagewormCore;
		}};
		{DEP_RC} /* RevenueCat */ = {{
			isa = XCSwiftPackageProductDependency;
			package = {REMOTE_PKG} /* XCRemoteSwiftPackageReference "purchases-ios-spm" */;
			productName = RevenueCat;
		}};""")
parts.append("/* End XCSwiftPackageProductDependency section */")
parts.append("\t};\n\trootObject = " + PROJECT + " /* Project object */;\n}\n")

text = "\n".join(parts)
# Fix remoteInfo names
text = text.replace("remoteInfo = PagewormShieldConfiguration;", "remoteInfo = PagewormShieldConfiguration;")
(PROJ / "project.pbxproj").write_text(text)
print(f"wrote {PROJ / 'project.pbxproj'} ({len(text)} bytes)")

# Uniqueness check
import re
ids = re.findall(r"\bA1\d{22}\b", text)
from collections import Counter
dups = [i for i, c in Counter(ids).items() if c > 8]
print("id count", len(ids), "unique", len(set(ids)))
