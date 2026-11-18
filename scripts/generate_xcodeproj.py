#!/usr/bin/env python3
"""Write Pageworm.xcodeproj from the source tree. Run from the repo root."""

import hashlib
import os
import textwrap
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "Pageworm.xcodeproj"


def pid(name: str) -> str:
    return hashlib.sha1(f"pageworm:{name}".encode()).hexdigest()[:24].upper()


def quote(value) -> str:
    if isinstance(value, bool):
        return "YES" if value else "NO"
    if isinstance(value, int) and not isinstance(value, bool):
        return str(value)
    text = str(value)
    if " /* " in text:
        return text
    if __import__("re").fullmatch(r"[A-Za-z0-9_./+]+", text):
        return text
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def render(obj, indent=0) -> str:
    pad = "\t" * indent
    if isinstance(obj, dict):
        if not obj:
            return "{\n" + pad + "}"
        lines = ["{"]
        for key, value in obj.items():
            lines.append(f"{pad}\t{key} = {render(value, indent + 1)};")
        lines.append(pad + "}")
        return "\n".join(lines)
    if isinstance(obj, list):
        if not obj:
            return "(\n" + pad + ")"
        lines = ["("]
        for value in obj:
            lines.append(f"{pad}\t{quote(value) if not isinstance(value, (dict, list)) else render(value, indent + 1)},")
        lines.append(pad + ")")
        return "\n".join(lines)
    return quote(obj)


class Writer:
    def __init__(self):
        self.sections = {}

    def add(self, section, object_id, isa, body, comment):
        body = {"isa": isa, **body}
        self.sections.setdefault(section, []).append((object_id, comment, body))

    def dump(self) -> str:
        chunks = [
            "// !$*UTF8*$!",
            "{",
            "\tarchiveVersion = 1;",
            "\tclasses = {\n\t};",
            "\tobjectVersion = 56;",
            "\tobjects = {",
        ]
        for section, items in self.sections.items():
            chunks.append(f"\n/* Begin {section} section */")
            for object_id, comment, body in items:
                rendered = render(body, 2)
                chunks.append(f"\t\t{object_id} /* {comment} */ = {rendered};")
            chunks.append(f"/* End {section} section */")
        chunks.append("\t};")
        chunks.append(f"\trootObject = {pid('project')} /* Project object */;")
        chunks.append("}")
        return "\n".join(chunks) + "\n"


def collect(base: Path):
    files = []
    if not base.exists():
        return files
    for dirpath, dirnames, filenames in os.walk(base):
        directory = Path(dirpath)
        kept = []
        for name in sorted(dirnames):
            if name.startswith("."):
                continue
            if name.endswith(".xcassets"):
                files.append(directory / name)
            else:
                kept.append(name)
        dirnames[:] = kept
        for name in sorted(filenames):
            if name.startswith("."):
                continue
            files.append(directory / name)
    return files


def file_type(path: Path) -> str:
    name = path.name
    if name.endswith(".xcassets"):
        return "folder.assetcatalog"
    if name.endswith(".entitlements"):
        return "text.plist.entitlements"
    if name.endswith(".xcprivacy"):
        return "text.xml"
    if name.endswith(".plist"):
        return "text.plist.xml"
    if name.endswith(".swift"):
        return "sourcecode.swift"
    if name.endswith(".png"):
        return "image.png"
    return "text"


def main():
    app_files = collect(ROOT / "App") + collect(ROOT / "Shared" / "Blocking")
    targets = [
        {
            "name": "Pageworm",
            "product": "Pageworm.app",
            "product_type": "com.apple.product-type.application",
            "explicit": "wrapper.application",
            "bundle": "com.pageworm.app",
            "info": "App/Info.plist",
            "entitlements": "App/Pageworm.entitlements",
            "sources": [p for p in app_files if p.suffix == ".swift"],
            "resources": [p for p in app_files if p.suffix in {".xcprivacy"} or p.name.endswith(".xcassets")],
            "packages": ["PagewormCore", "PagewormDesign", "PagewormActivity", "RevenueCat"],
            "embed": ["ShieldConfiguration", "ShieldAction", "DeviceActivityMonitor", "DeviceActivityReport", "PagewormWidget"],
            "extension": False,
            "display": "Pageworm",
        },
        {
            "name": "ShieldConfiguration",
            "product": "ShieldConfiguration.appex",
            "product_type": "com.apple.product-type.app-extension",
            "explicit": "wrapper.app-extension",
            "bundle": "com.pageworm.app.shield-configuration",
            "info": "Extensions/ShieldConfiguration/Info.plist",
            "entitlements": "Extensions/ShieldConfiguration/ShieldConfiguration.entitlements",
            "sources": collect(ROOT / "Extensions" / "ShieldConfiguration"),
            "resources": [],
            "packages": ["PagewormCore", "PagewormDesign"],
            "embed": [],
            "extension": True,
            "display": "Shield",
        },
        {
            "name": "ShieldAction",
            "product": "ShieldAction.appex",
            "product_type": "com.apple.product-type.app-extension",
            "explicit": "wrapper.app-extension",
            "bundle": "com.pageworm.app.shield-action",
            "info": "Extensions/ShieldAction/Info.plist",
            "entitlements": "Extensions/ShieldAction/ShieldAction.entitlements",
            "sources": [p for p in collect(ROOT / "Extensions" / "ShieldAction") if p.suffix == ".swift"],
            "resources": [],
            "packages": ["PagewormCore", "PagewormDesign"],
            "embed": [],
            "extension": True,
            "display": "Shield Action",
        },
        {
            "name": "DeviceActivityMonitor",
            "product": "DeviceActivityMonitor.appex",
            "product_type": "com.apple.product-type.app-extension",
            "explicit": "wrapper.app-extension",
            "bundle": "com.pageworm.app.monitor",
            "info": "Extensions/DeviceActivityMonitor/Info.plist",
            "entitlements": "Extensions/DeviceActivityMonitor/Monitor.entitlements",
            "sources": [p for p in collect(ROOT / "Extensions" / "DeviceActivityMonitor") + collect(ROOT / "Shared" / "Blocking") if p.suffix == ".swift"],
            "resources": [],
            "packages": ["PagewormCore", "PagewormDesign"],
            "embed": [],
            "extension": True,
            "display": "Monitor",
        },
        {
            "name": "DeviceActivityReport",
            "product": "DeviceActivityReport.appex",
            "product_type": "com.apple.product-type.app-extension",
            "explicit": "wrapper.app-extension",
            "bundle": "com.pageworm.app.report",
            "info": "Extensions/DeviceActivityReport/Info.plist",
            "entitlements": "Extensions/DeviceActivityReport/Report.entitlements",
            "sources": [p for p in collect(ROOT / "Extensions" / "DeviceActivityReport") if p.suffix == ".swift"],
            "resources": [],
            "packages": ["PagewormCore", "PagewormDesign"],
            "embed": [],
            "extension": True,
            "display": "Report",
        },
        {
            "name": "PagewormWidget",
            "product": "PagewormWidget.appex",
            "product_type": "com.apple.product-type.app-extension",
            "explicit": "wrapper.app-extension",
            "bundle": "com.pageworm.app.widget",
            "info": "Extensions/Widget/Info.plist",
            "entitlements": "Extensions/Widget/Widget.entitlements",
            "sources": [p for p in collect(ROOT / "Extensions" / "Widget") if p.suffix == ".swift"],
            "resources": [],
            "packages": ["PagewormCore", "PagewormDesign", "PagewormActivity"],
            "embed": [],
            "extension": True,
            "display": "Pageworm",
        },
    ]

    for target in targets:
        target["sources"] = [p for p in target["sources"] if p.suffix == ".swift"]

    all_paths = []
    for target in targets:
        all_paths.extend(target["sources"])
        all_paths.extend(target["resources"])
        all_paths.append(ROOT / target["info"])
        all_paths.append(ROOT / target["entitlements"])
    unique_paths = sorted(set(all_paths), key=lambda p: p.relative_to(ROOT).as_posix())

    writer = Writer()
    file_ids = {path: pid(f"file:{path.relative_to(ROOT).as_posix()}") for path in unique_paths}

    for path in unique_paths:
        rel = path.relative_to(ROOT).as_posix()
        writer.add(
            "PBXFileReference",
            file_ids[path],
            "PBXFileReference",
            {
                "lastKnownFileType": file_type(path),
                "path": path.name,
                "sourceTree": "<group>",
            },
            path.name,
        )

    product_ids = {}
    for target in targets:
        product_ids[target["name"]] = pid(f"product:{target['name']}")
        writer.add(
            "PBXFileReference",
            product_ids[target["name"]],
            "PBXFileReference",
            {
                "explicitFileType": target["explicit"],
                "includeInIndex": 0,
                "path": target["product"],
                "sourceTree": "BUILT_PRODUCTS_DIR",
            },
            target["product"],
        )

    # Groups mirror the repo folders that contain project files.
    nodes = {}

    def ensure_group(parts):
        key = tuple(parts)
        if key in nodes:
            return nodes[key]
        nodes[key] = {"id": pid("group:" + "/".join(parts) if parts else "root"), "children": [], "name": parts[-1] if parts else "Pageworm", "path": parts[-1] if parts else None}
        if parts:
            parent = ensure_group(parts[:-1])
            parent["children"].append(nodes[key]["id"] + f" /* {parts[-1]} */")
        return nodes[key]

    ensure_group(())
    for path in unique_paths:
        rel_parts = path.relative_to(ROOT).parts
        parent = ensure_group(rel_parts[:-1])
        parent["children"].append(file_ids[path] + f" /* {path.name} */")

    products_id = pid("group:products")
    writer.add(
        "PBXGroup",
        products_id,
        "PBXGroup",
        {
            "children": [f"{product_ids[t['name']]} /* {t['product']} */" for t in targets],
            "name": "Products",
            "sourceTree": "<group>",
        },
        "Products",
    )
    nodes[()]["children"].append(f"{products_id} /* Products */")

    for key in sorted(nodes, key=lambda item: (len(item), item)):
        node = nodes[key]
        body = {
            "children": sorted(set(node["children"])),
            "sourceTree": "<group>",
        }
        if key == ():
            body["children"] = sorted(c for c in set(node["children"]) if "Products" not in c) + [f"{products_id} /* Products */"]
        if node["path"]:
            body["path"] = node["path"]
        else:
            body["name"] = "Pageworm"
        writer.add("PBXGroup", node["id"], "PBXGroup", body, node["name"] if key else "Pageworm")

    local_packages = {
        "PagewormCore": "Packages/PagewormCore",
        "PagewormDesign": "Packages/PagewormDesign",
        "PagewormActivity": "Packages/PagewormActivity",
    }
    package_ref_ids = {name: pid(f"pkgref:{name}") for name in list(local_packages) + ["RevenueCat"]}
    for name, path in local_packages.items():
        writer.add(
            "XCLocalSwiftPackageReference",
            package_ref_ids[name],
            "XCLocalSwiftPackageReference",
            {"relativePath": path},
            f"XCLocalSwiftPackageReference \"{name}\"",
        )
    writer.add(
        "XCRemoteSwiftPackageReference",
        package_ref_ids["RevenueCat"],
        "XCRemoteSwiftPackageReference",
        {
            "repositoryURL": "https://github.com/RevenueCat/purchases-ios.git",
            "requirement": {
                "kind": "upToNextMajorVersion",
                "minimumVersion": "5.103.1",
            },
        },
        "XCRemoteSwiftPackageReference \"purchases-ios\"",
    )

    product_dep_ids = {}
    for name in ["PagewormCore", "PagewormDesign", "PagewormActivity", "RevenueCat"]:
        product_dep_ids[name] = pid(f"pkgproduct:{name}")
        writer.add(
            "XCSwiftPackageProductDependency",
            product_dep_ids[name],
            "XCSwiftPackageProductDependency",
            {"package": f"{package_ref_ids[name]} /* {name} */", "productName": name},
            name,
        )

    def build_file(key, comment, **body):
        object_id = pid(key)
        writer.add("PBXBuildFile", object_id, "PBXBuildFile", body, comment)
        return object_id

    for target in targets:
        source_builds = []
        for path in target["sources"]:
            source_builds.append(
                build_file(
                    f"build:{target['name']}:{path.relative_to(ROOT).as_posix()}",
                    f"{path.name} in Sources",
                    fileRef=f"{file_ids[path]} /* {path.name} */",
                )
            )
        resource_builds = []
        for path in target["resources"]:
            resource_builds.append(
                build_file(
                    f"resource:{target['name']}:{path.relative_to(ROOT).as_posix()}",
                    f"{path.name} in Resources",
                    fileRef=f"{file_ids[path]} /* {path.name} */",
                )
            )
        framework_builds = []
        for package in target["packages"]:
            framework_builds.append(
                build_file(
                    f"framework:{target['name']}:{package}",
                    f"{package} in Frameworks",
                    productRef=f"{product_dep_ids[package]} /* {package} */",
                )
            )
        embed_builds = []
        for embedded in target["embed"]:
            embed_builds.append(
                build_file(
                    f"embed:{embedded}",
                    f"{embedded}.appex in Embed Foundation Extensions",
                    fileRef=f"{product_ids[embedded]} /* {embedded}.appex */",
                    settings={"ATTRIBUTES": ["RemoveHeadersOnCopy"]},
                )
            )

        sources_phase = pid(f"sources:{target['name']}")
        frameworks_phase = pid(f"frameworks:{target['name']}")
        resources_phase = pid(f"resources:{target['name']}")
        writer.add(
            "PBXSourcesBuildPhase",
            sources_phase,
            "PBXSourcesBuildPhase",
            {"buildActionMask": 2147483647, "files": [f"{item} /* source */" for item in source_builds], "runOnlyForDeploymentPostprocessing": 0},
            "Sources",
        )
        writer.add(
            "PBXFrameworksBuildPhase",
            frameworks_phase,
            "PBXFrameworksBuildPhase",
            {"buildActionMask": 2147483647, "files": [f"{item} /* framework */" for item in framework_builds], "runOnlyForDeploymentPostprocessing": 0},
            "Frameworks",
        )
        writer.add(
            "PBXResourcesBuildPhase",
            resources_phase,
            "PBXResourcesBuildPhase",
            {"buildActionMask": 2147483647, "files": [f"{item} /* resource */" for item in resource_builds], "runOnlyForDeploymentPostprocessing": 0},
            "Resources",
        )
        phases = [sources_phase, frameworks_phase, resources_phase]
        if embed_builds:
            embed_phase = pid("embed")
            writer.add(
                "PBXCopyFilesBuildPhase",
                embed_phase,
                "PBXCopyFilesBuildPhase",
                {
                    "buildActionMask": 2147483647,
                    "dstPath": "",
                    "dstSubfolderSpec": 13,
                    "files": [f"{item} /* embed */" for item in embed_builds],
                    "name": "Embed Foundation Extensions",
                    "runOnlyForDeploymentPostprocessing": 0,
                },
                "Embed Foundation Extensions",
            )
            phases.append(embed_phase)

        dependency_ids = []
        for embedded in target["embed"]:
            proxy = pid(f"proxy:{embedded}")
            dependency = pid(f"dependency:{embedded}")
            writer.add(
                "PBXContainerItemProxy",
                proxy,
                "PBXContainerItemProxy",
                {
                    "containerPortal": f"{pid('project')} /* Project object */",
                    "proxyType": 1,
                    "remoteGlobalIDString": pid(f"target:{embedded}"),
                    "remoteInfo": embedded,
                },
                "PBXContainerItemProxy",
            )
            writer.add(
                "PBXTargetDependency",
                dependency,
                "PBXTargetDependency",
                {"target": f"{pid(f'target:{embedded}')} /* {embedded} */", "targetProxy": f"{proxy} /* PBXContainerItemProxy */"},
                "PBXTargetDependency",
            )
            dependency_ids.append(f"{dependency} /* PBXTargetDependency */")

        debug_id = pid(f"config:{target['name']}:Debug")
        release_id = pid(f"config:{target['name']}:Release")
        list_id = pid(f"configlist:{target['name']}")
        common = {
            "CODE_SIGN_ENTITLEMENTS": target["entitlements"],
            "CODE_SIGN_STYLE": "Automatic",
            "CURRENT_PROJECT_VERSION": 1,
            "GENERATE_INFOPLIST_FILE": "YES",
            "INFOPLIST_FILE": target["info"],
            "INFOPLIST_KEY_CFBundleDisplayName": target["display"],
            "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
            "LD_RUNPATH_SEARCH_PATHS": [
                "$(inherited)",
                "@executable_path/Frameworks",
            ]
            + (["@executable_path/../../Frameworks"] if target["extension"] else []),
            "MARKETING_VERSION": "1.0",
            "PRODUCT_BUNDLE_IDENTIFIER": target["bundle"],
            "PRODUCT_NAME": "$(TARGET_NAME)",
            "SKIP_INSTALL": "YES" if target["extension"] else "NO",
            "SWIFT_EMIT_LOC_STRINGS": "YES",
            "SWIFT_VERSION": "5.0",
            "TARGETED_DEVICE_FAMILY": "1",
        }
        if target["extension"]:
            common["APPLICATION_EXTENSION_API_ONLY"] = "YES"
        else:
            common["ASSETCATALOG_COMPILER_APPICON_NAME"] = "AppIcon"
            common["ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME"] = "AccentColor"
            common["ENABLE_PREVIEWS"] = "YES"
            common["SUPPORTS_MACCATALYST"] = "NO"
        for config_name, config_id in (("Debug", debug_id), ("Release", release_id)):
            writer.add(
                "XCBuildConfiguration",
                config_id,
                "XCBuildConfiguration",
                {"buildSettings": common, "name": config_name},
                f"{config_name} {target['name']}",
            )
        writer.add(
            "XCConfigurationList",
            list_id,
            "XCConfigurationList",
            {
                "buildConfigurations": [f"{debug_id} /* Debug */", f"{release_id} /* Release */"],
                "defaultConfigurationIsVisible": 0,
                "defaultConfigurationName": "Release",
            },
            f"Build configuration list for {target['name']}",
        )
        target_id = pid(f"target:{target['name']}")
        writer.add(
            "PBXNativeTarget",
            target_id,
            "PBXNativeTarget",
            {
                "buildConfigurationList": f"{list_id} /* configs */",
                "buildPhases": [f"{phase} /* phase */" for phase in phases],
                "buildRules": [],
                "dependencies": dependency_ids,
                "name": target["name"],
                "packageProductDependencies": [f"{product_dep_ids[name]} /* {name} */" for name in target["packages"]],
                "productName": target["name"],
                "productReference": f"{product_ids[target['name']]} /* {target['product']} */",
                "productType": target["product_type"],
            },
            target["name"],
        )

    project_debug = pid("config:project:Debug")
    project_release = pid("config:project:Release")
    project_list = pid("configlist:project")
    shared_debug = {
        "ALWAYS_SEARCH_USER_PATHS": "NO",
        "CLANG_ENABLE_MODULES": "YES",
        "CLANG_ENABLE_OBJC_ARC": "YES",
        "COPY_PHASE_STRIP": "NO",
        "DEBUG_INFORMATION_FORMAT": "dwarf",
        "ENABLE_NS_ASSERTIONS": "YES",
        "ENABLE_STRICT_OBJC_MSGSEND": "YES",
        "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
        "GCC_DYNAMIC_NO_PIC": "NO",
        "GCC_OPTIMIZATION_LEVEL": "0",
        "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
        "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE",
        "ONLY_ACTIVE_ARCH": "YES",
        "SDKROOT": "iphoneos",
        "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG",
        "SWIFT_OPTIMIZATION_LEVEL": "-Onone",
        "SWIFT_VERSION": "5.0",
        "TARGETED_DEVICE_FAMILY": "1",
    }
    shared_release = {
        **shared_debug,
        "COPY_PHASE_STRIP": "NO",
        "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
        "ENABLE_NS_ASSERTIONS": "NO",
        "GCC_OPTIMIZATION_LEVEL": "s",
        "MTL_ENABLE_DEBUG_INFO": "NO",
        "ONLY_ACTIVE_ARCH": "NO",
        "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "",
        "SWIFT_COMPILATION_MODE": "wholemodule",
        "SWIFT_OPTIMIZATION_LEVEL": "-O",
        "VALIDATE_PRODUCT": "YES",
    }
    writer.add("XCBuildConfiguration", project_debug, "XCBuildConfiguration", {"buildSettings": shared_debug, "name": "Debug"}, "Debug project")
    writer.add("XCBuildConfiguration", project_release, "XCBuildConfiguration", {"buildSettings": shared_release, "name": "Release"}, "Release project")
    writer.add(
        "XCConfigurationList",
        project_list,
        "XCConfigurationList",
        {
            "buildConfigurations": [f"{project_debug} /* Debug */", f"{project_release} /* Release */"],
            "defaultConfigurationIsVisible": 0,
            "defaultConfigurationName": "Release",
        },
        "Build configuration list for project",
    )

    attributes = {
        "BuildIndependentTargetsInParallel": 1,
        "LastSwiftUpdateCheck": 1540,
        "LastUpgradeCheck": 1540,
        "TargetAttributes": {pid(f"target:{target['name']}"): {"CreatedOnToolsVersion": "15.4"} for target in targets},
    }
    writer.add(
        "PBXProject",
        pid("project"),
        "PBXProject",
        {
            "attributes": attributes,
            "buildConfigurationList": f"{project_list} /* configs */",
            "compatibilityVersion": "Xcode 14.0",
            "developmentRegion": "en",
            "hasScannedForEncodings": 0,
            "knownRegions": ["en", "Base"],
            "mainGroup": f"{nodes[()]['id']} /* Pageworm */",
            "packageReferences": [f"{package_ref_ids[name]} /* {name} */" for name in ["PagewormCore", "PagewormDesign", "PagewormActivity", "RevenueCat"]],
            "productRefGroup": f"{products_id} /* Products */",
            "projectDirPath": "",
            "projectRoot": "",
            "targets": [f"{pid(f'target:{target['name']}')} /* {target['name']} */" for target in targets],
        },
        "Project object",
    )

    PROJECT.mkdir(exist_ok=True)
    (PROJECT / "project.pbxproj").write_text(writer.dump())
    scheme_dir = PROJECT / "xcshareddata" / "xcschemes"
    scheme_dir.mkdir(parents=True, exist_ok=True)
    app_id = pid("target:Pageworm")
    scheme = textwrap.dedent(
        f"""\
        <?xml version="1.0" encoding="UTF-8"?>
        <Scheme
           LastUpgradeVersion = "1540"
           version = "1.7">
           <BuildAction
              parallelizeBuildables = "YES"
              buildImplicitDependencies = "YES">
              <BuildActionEntries>
                 <BuildActionEntry
                    buildForTesting = "YES"
                    buildForRunning = "YES"
                    buildForProfiling = "YES"
                    buildForArchiving = "YES"
                    buildForAnalyzing = "YES">
                    <BuildableReference
                       BuildableIdentifier = "primary"
                       BlueprintIdentifier = "{app_id}"
                       BuildableName = "Pageworm.app"
                       BlueprintName = "Pageworm"
                       ReferencedContainer = "container:Pageworm.xcodeproj">
                    </BuildableReference>
                 </BuildActionEntry>
              </BuildActionEntries>
           </BuildAction>
           <TestAction
              buildConfiguration = "Debug"
              selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
              selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
              shouldUseLaunchSchemeArgsEnv = "YES">
           </TestAction>
           <LaunchAction
              buildConfiguration = "Debug"
              selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
              selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
              launchStyle = "0"
              useCustomWorkingDirectory = "NO"
              ignoresPersistentStateOnLaunch = "NO"
              debugDocumentVersioning = "YES"
              debugServiceExtension = "internal"
              allowLocationSimulation = "YES">
              <BuildableProductRunnable
                 runnableDebuggingMode = "0">
                 <BuildableReference
                    BuildableIdentifier = "primary"
                    BlueprintIdentifier = "{app_id}"
                    BuildableName = "Pageworm.app"
                    BlueprintName = "Pageworm"
                    ReferencedContainer = "container:Pageworm.xcodeproj">
                 </BuildableReference>
              </BuildableProductRunnable>
           </LaunchAction>
           <ProfileAction
              buildConfiguration = "Release"
              shouldUseLaunchSchemeArgsEnv = "YES"
              savedToolIdentifier = ""
              useCustomWorkingDirectory = "NO"
              debugDocumentVersioning = "YES">
              <BuildableProductRunnable
                 runnableDebuggingMode = "0">
                 <BuildableReference
                    BuildableIdentifier = "primary"
                    BlueprintIdentifier = "{app_id}"
                    BuildableName = "Pageworm.app"
                    BlueprintName = "Pageworm"
                    ReferencedContainer = "container:Pageworm.xcodeproj">
                 </BuildableReference>
              </BuildableProductRunnable>
           </ProfileAction>
           <AnalyzeAction
              buildConfiguration = "Debug">
           </AnalyzeAction>
           <ArchiveAction
              buildConfiguration = "Release"
              revealArchiveInOrganizer = "YES">
           </ArchiveAction>
        </Scheme>
        """
    )
    (scheme_dir / "Pageworm.xcscheme").write_text(scheme)
    workspace = PROJECT / "project.xcworkspace"
    workspace.mkdir(exist_ok=True)
    (workspace / "contents.xcworkspacedata").write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n<Workspace\n   version = "1.0">\n   <FileRef\n      location = "self:">\n   </FileRef>\n</Workspace>\n'
    )
    resolved_dir = workspace / "xcshareddata" / "swiftpm"
    resolved_dir.mkdir(parents=True, exist_ok=True)
    (resolved_dir / "Package.resolved").write_text(
        """{
  "pins" : [
    {
      "identity" : "purchases-ios",
      "kind" : "remoteSourceControl",
      "location" : "https://github.com/RevenueCat/purchases-ios.git",
      "state" : {
        "revision" : "5f7c6a01399038a20fe568d4c68db66b55865f6c",
        "version" : "5.103.1"
      }
    }
  ],
  "version" : 2
}
"""
    )
    print(f"Wrote {PROJECT / 'project.pbxproj'}")
    swift_files = list(ROOT.rglob("*.swift"))
    swift_files = [p for p in swift_files if ".build" not in p.parts and "Packages" not in p.parts[:1] or "Packages" in p.parts]
    project_sources = [p for p in swift_files if "Packages" not in p.parts and ".build" not in p.parts]
    missing = [p.relative_to(ROOT).as_posix() for p in project_sources if p not in unique_paths]
    print(f"App/extension Swift files: {len(project_sources)}; missing from project: {missing}")


if __name__ == "__main__":
    main()
