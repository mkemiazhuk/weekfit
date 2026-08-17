#!/usr/bin/env python3
"""Inject WeekFitWidget extension + WeekFitWidgetShared local package into project.pbxproj."""

from pathlib import Path

PBX = Path("/Users/maxk/Dev/WeekFit/WeekFit.xcodeproj/project.pbxproj")
text = PBX.read_text()

# Idempotent guard
if "WeekFitWidgetShared" in text and "WeekFitWidget.appex" in text:
    print("already patched")
    raise SystemExit(0)

# --- PBXBuildFile ---
text = text.replace(
    "/* Begin PBXBuildFile section */\n",
    """/* Begin PBXBuildFile section */
\t\tW10000012FB2403E006A4D40 /* WeekFitWidgetShared in Frameworks */ = {isa = PBXBuildFile; productRef = W100000A2FB2403E006A4D40 /* WeekFitWidgetShared */; };
\t\tW10000022FB2403E006A4D40 /* WeekFitWidgetShared in Frameworks */ = {isa = PBXBuildFile; productRef = W100000B2FB2403E006A4D40 /* WeekFitWidgetShared */; };
\t\tW10000032FB2403E006A4D40 /* WeekFitWidget.appex in Embed Foundation Extensions */ = {isa = PBXBuildFile; fileRef = W10000102FB2403E006A4D40 /* WeekFitWidget.appex */; settings = {ATTRIBUTES = (RemoveHeadersOnCopy, ); }; };
""",
)

# --- PBXContainerItemProxy ---
text = text.replace(
    "/* End PBXContainerItemProxy section */",
    """\t\tW10000202FB2403E006A4D40 /* PBXContainerItemProxy */ = {
\t\t\tisa = PBXContainerItemProxy;
\t\t\tcontainerPortal = 55E7BBDD2FB2403E006A4D20 /* Project object */;
\t\t\tproxyType = 1;
\t\t\tremoteGlobalIDString = W10000302FB2403E006A4D40;
\t\t\tremoteInfo = WeekFitWidget;
\t\t};
/* End PBXContainerItemProxy section */""",
)

# --- PBXCopyFilesBuildPhase ---
text = text.replace(
    "/* Begin PBXFileReference section */",
    """/* Begin PBXCopyFilesBuildPhase section */
\t\tW10000402FB2403E006A4D40 /* Embed Foundation Extensions */ = {
\t\t\tisa = PBXCopyFilesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tdstPath = "";
\t\t\tdstSubfolderSpec = 13;
\t\t\tfiles = (
\t\t\t\tW10000032FB2403E006A4D40 /* WeekFitWidget.appex in Embed Foundation Extensions */,
\t\t\t);
\t\t\tname = "Embed Foundation Extensions";
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
/* End PBXCopyFilesBuildPhase section */

/* Begin PBXFileReference section */""",
)

# --- PBXFileReference ---
text = text.replace(
    "\t\t55E7BBFC2FB24040006A4D20 /* WeekFitUITests.xctest */ = {isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = WeekFitUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR; };\n/* End PBXFileReference section */",
    """\t\t55E7BBFC2FB24040006A4D20 /* WeekFitUITests.xctest */ = {isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = WeekFitUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR; };
\t\tW10000102FB2403E006A4D40 /* WeekFitWidget.appex */ = {isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = WeekFitWidget.appex; sourceTree = BUILT_PRODUCTS_DIR; };
/* End PBXFileReference section */""",
)

# --- Exception set for widget Info.plist ---
text = text.replace(
    "/* End PBXFileSystemSynchronizedBuildFileExceptionSet section */",
    """\t\tW10000502FB2403E006A4D40 /* Exceptions for "WeekFitWidget" folder in "WeekFitWidget" target */ = {
\t\t\tisa = PBXFileSystemSynchronizedBuildFileExceptionSet;
\t\t\tmembershipExceptions = (
\t\t\t\tInfo.plist,
\t\t\t);
\t\t\ttarget = W10000302FB2403E006A4D40 /* WeekFitWidget */;
\t\t};
/* End PBXFileSystemSynchronizedBuildFileExceptionSet section */""",
)

# --- Synchronized root group ---
text = text.replace(
    "\t\t55E7BBFF2FB24040006A4D20 /* WeekFitUITests */ = {\n\t\t\tisa = PBXFileSystemSynchronizedRootGroup;\n\t\t\tpath = WeekFitUITests;\n\t\t\tsourceTree = \"<group>\";\n\t\t};\n/* End PBXFileSystemSynchronizedRootGroup section */",
    """\t\t55E7BBFF2FB24040006A4D20 /* WeekFitUITests */ = {
\t\t\tisa = PBXFileSystemSynchronizedRootGroup;
\t\t\tpath = WeekFitUITests;
\t\t\tsourceTree = "<group>";
\t\t};
\t\tW10000602FB2403E006A4D40 /* WeekFitWidget */ = {
\t\t\tisa = PBXFileSystemSynchronizedRootGroup;
\t\t\texceptions = (
\t\t\t\tW10000502FB2403E006A4D40 /* Exceptions for "WeekFitWidget" folder in "WeekFitWidget" target */,
\t\t\t);
\t\t\tpath = WeekFitWidget;
\t\t\tsourceTree = "<group>";
\t\t};
/* End PBXFileSystemSynchronizedRootGroup section */""",
)

# --- Frameworks phases ---
text = text.replace(
    """\t\t55E7BBE22FB2403E006A4D20 /* Frameworks */ = {
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\t5552A8C62FE4968100A4172A /* WeekFitWorkoutMetrics in Frameworks */,
\t\t\t\t5552A8C72FE4968100A4172B /* WeekFitCoachCore in Frameworks */,
\t\t\t\t5552A8C82FE4968100A4172C /* WeekFitPlanner in Frameworks */,
\t\t\t\t5552A8C92FE4968100A4172D /* WeekFitHealthKit in Frameworks */,
\t\t\t\tF10000042FB2403E006A4D33 /* FirebaseAnalyticsCore in Frameworks */,
\t\t\t\tF10000052FB2403E006A4D34 /* FirebaseCrashlytics in Frameworks */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};""",
    """\t\t55E7BBE22FB2403E006A4D20 /* Frameworks */ = {
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\t5552A8C62FE4968100A4172A /* WeekFitWorkoutMetrics in Frameworks */,
\t\t\t\t5552A8C72FE4968100A4172B /* WeekFitCoachCore in Frameworks */,
\t\t\t\t5552A8C82FE4968100A4172C /* WeekFitPlanner in Frameworks */,
\t\t\t\t5552A8C92FE4968100A4172D /* WeekFitHealthKit in Frameworks */,
\t\t\t\tW10000012FB2403E006A4D40 /* WeekFitWidgetShared in Frameworks */,
\t\t\t\tF10000042FB2403E006A4D33 /* FirebaseAnalyticsCore in Frameworks */,
\t\t\t\tF10000052FB2403E006A4D34 /* FirebaseCrashlytics in Frameworks */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
\t\tW10000702FB2403E006A4D40 /* Frameworks */ = {
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\tW10000022FB2403E006A4D40 /* WeekFitWidgetShared in Frameworks */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};""",
)

# --- Root group children ---
text = text.replace(
    """\t\t55E7BBDC2FB2403E006A4D20 = {
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t55E7BBE72FB2403E006A4D20 /* WeekFit */,
\t\t\t\t55E7BBF52FB24040006A4D20 /* WeekFitTests */,
\t\t\t\t55E7BBFF2FB24040006A4D20 /* WeekFitUITests */,
\t\t\t\t55E7BBE62FB2403E006A4D20 /* Products */,
\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t};""",
    """\t\t55E7BBDC2FB2403E006A4D20 = {
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t55E7BBE72FB2403E006A4D20 /* WeekFit */,
\t\t\t\tW10000602FB2403E006A4D40 /* WeekFitWidget */,
\t\t\t\t55E7BBF52FB24040006A4D20 /* WeekFitTests */,
\t\t\t\t55E7BBFF2FB24040006A4D20 /* WeekFitUITests */,
\t\t\t\t55E7BBE62FB2403E006A4D20 /* Products */,
\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t};""",
)

text = text.replace(
    """\t\t55E7BBE62FB2403E006A4D20 /* Products */ = {
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t55E7BBE52FB2403E006A4D20 /* WeekFit.app */,
\t\t\t\t55E7BBF22FB24040006A4D20 /* WeekFitTests.xctest */,
\t\t\t\t55E7BBFC2FB24040006A4D20 /* WeekFitUITests.xctest */,
\t\t\t);
\t\t\tname = Products;
\t\t\tsourceTree = "<group>";
\t\t};""",
    """\t\t55E7BBE62FB2403E006A4D20 /* Products */ = {
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t55E7BBE52FB2403E006A4D20 /* WeekFit.app */,
\t\t\t\tW10000102FB2403E006A4D40 /* WeekFitWidget.appex */,
\t\t\t\t55E7BBF22FB24040006A4D20 /* WeekFitTests.xctest */,
\t\t\t\t55E7BBFC2FB24040006A4D20 /* WeekFitUITests.xctest */,
\t\t\t);
\t\t\tname = Products;
\t\t\tsourceTree = "<group>";
\t\t};""",
)

# --- Native targets: WeekFit deps + widget target ---
text = text.replace(
    """\t\t55E7BBE42FB2403E006A4D20 /* WeekFit */ = {
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = 55E7BC062FB24040006A4D20 /* Build configuration list for PBXNativeTarget "WeekFit" */;
\t\t\tbuildPhases = (
\t\t\t\t55E7BBE12FB2403E006A4D20 /* Sources */,
\t\t\t\t55E7BBE22FB2403E006A4D20 /* Frameworks */,
\t\t\t\t55E7BBE32FB2403E006A4D20 /* Resources */,
\t\t\t\tF10000062FB2403E006A4D35 /* Upload Crashlytics dSYM */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tfileSystemSynchronizedGroups = (
\t\t\t\t55E7BBE72FB2403E006A4D20 /* WeekFit */,
\t\t\t);
\t\t\tname = WeekFit;
\t\t\tpackageProductDependencies = (
\t\t\t\tA10000022FB2403E006A4D20 /* WeekFitWorkoutMetrics */,
\t\t\t\tA10000042FB2403E006A4D22 /* WeekFitCoachCore */,
\t\t\t\tA10000062FB2403E006A4D24 /* WeekFitPlanner */,
\t\t\t\tA10000082FB2403E006A4D26 /* WeekFitHealthKit */,
\t\t\t\tF10000022FB2403E006A4D31 /* FirebaseAnalyticsCore */,
\t\t\t\tF10000032FB2403E006A4D32 /* FirebaseCrashlytics */,
\t\t\t);
\t\t\tproductName = WeekFit;
\t\t\tproductReference = 55E7BBE52FB2403E006A4D20 /* WeekFit.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t};""",
    """\t\t55E7BBE42FB2403E006A4D20 /* WeekFit */ = {
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = 55E7BC062FB24040006A4D20 /* Build configuration list for PBXNativeTarget "WeekFit" */;
\t\t\tbuildPhases = (
\t\t\t\t55E7BBE12FB2403E006A4D20 /* Sources */,
\t\t\t\t55E7BBE22FB2403E006A4D20 /* Frameworks */,
\t\t\t\t55E7BBE32FB2403E006A4D20 /* Resources */,
\t\t\t\tW10000402FB2403E006A4D40 /* Embed Foundation Extensions */,
\t\t\t\tF10000062FB2403E006A4D35 /* Upload Crashlytics dSYM */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t\tW10000802FB2403E006A4D40 /* PBXTargetDependency */,
\t\t\t);
\t\t\tfileSystemSynchronizedGroups = (
\t\t\t\t55E7BBE72FB2403E006A4D20 /* WeekFit */,
\t\t\t);
\t\t\tname = WeekFit;
\t\t\tpackageProductDependencies = (
\t\t\t\tA10000022FB2403E006A4D20 /* WeekFitWorkoutMetrics */,
\t\t\t\tA10000042FB2403E006A4D22 /* WeekFitCoachCore */,
\t\t\t\tA10000062FB2403E006A4D24 /* WeekFitPlanner */,
\t\t\t\tA10000082FB2403E006A4D26 /* WeekFitHealthKit */,
\t\t\t\tW100000A2FB2403E006A4D40 /* WeekFitWidgetShared */,
\t\t\t\tF10000022FB2403E006A4D31 /* FirebaseAnalyticsCore */,
\t\t\t\tF10000032FB2403E006A4D32 /* FirebaseCrashlytics */,
\t\t\t);
\t\t\tproductName = WeekFit;
\t\t\tproductReference = 55E7BBE52FB2403E006A4D20 /* WeekFit.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t};
\t\tW10000302FB2403E006A4D40 /* WeekFitWidget */ = {
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = W10000902FB2403E006A4D40 /* Build configuration list for PBXNativeTarget "WeekFitWidget" */;
\t\t\tbuildPhases = (
\t\t\t\tW10000A02FB2403E006A4D40 /* Sources */,
\t\t\t\tW10000702FB2403E006A4D40 /* Frameworks */,
\t\t\t\tW10000B02FB2403E006A4D40 /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tfileSystemSynchronizedGroups = (
\t\t\t\tW10000602FB2403E006A4D40 /* WeekFitWidget */,
\t\t\t);
\t\t\tname = WeekFitWidget;
\t\t\tpackageProductDependencies = (
\t\t\t\tW100000B2FB2403E006A4D40 /* WeekFitWidgetShared */,
\t\t\t);
\t\t\tproductName = WeekFitWidget;
\t\t\tproductReference = W10000102FB2403E006A4D40 /* WeekFitWidget.appex */;
\t\t\tproductType = "com.apple.product-type.app-extension";
\t\t};""",
)

# --- Project object TargetAttributes + packageReferences + targets ---
text = text.replace(
    """\t\t\t\tTargetAttributes = {
\t\t\t\t\t55E7BBE42FB2403E006A4D20 = {
\t\t\t\t\t\tCreatedOnToolsVersion = 26.4.1;
\t\t\t\t\t};
\t\t\t\t\t55E7BBF12FB24040006A4D20 = {
\t\t\t\t\t\tCreatedOnToolsVersion = 26.4.1;
\t\t\t\t\t\tTestTargetID = 55E7BBE42FB2403E006A4D20;
\t\t\t\t\t};
\t\t\t\t\t55E7BBFB2FB24040006A4D20 = {
\t\t\t\t\t\tCreatedOnToolsVersion = 26.4.1;
\t\t\t\t\t\tTestTargetID = 55E7BBE42FB2403E006A4D20;
\t\t\t\t\t};
\t\t\t\t};""",
    """\t\t\t\tTargetAttributes = {
\t\t\t\t\t55E7BBE42FB2403E006A4D20 = {
\t\t\t\t\t\tCreatedOnToolsVersion = 26.4.1;
\t\t\t\t\t};
\t\t\t\t\t55E7BBF12FB24040006A4D20 = {
\t\t\t\t\t\tCreatedOnToolsVersion = 26.4.1;
\t\t\t\t\t\tTestTargetID = 55E7BBE42FB2403E006A4D20;
\t\t\t\t\t};
\t\t\t\t\t55E7BBFB2FB24040006A4D20 = {
\t\t\t\t\t\tCreatedOnToolsVersion = 26.4.1;
\t\t\t\t\t\tTestTargetID = 55E7BBE42FB2403E006A4D20;
\t\t\t\t\t};
\t\t\t\t\tW10000302FB2403E006A4D40 = {
\t\t\t\t\t\tCreatedOnToolsVersion = 26.4.1;
\t\t\t\t\t};
\t\t\t\t};""",
)

text = text.replace(
    """\t\t\tpackageReferences = (
\t\t\t\tA10000012FB2403E006A4D20 /* XCLocalSwiftPackageReference "Packages/WeekFitWorkoutMetrics" */,
\t\t\t\tA10000032FB2403E006A4D21 /* XCLocalSwiftPackageReference "Packages/WeekFitCoachCore" */,
\t\t\t\tA10000052FB2403E006A4D23 /* XCLocalSwiftPackageReference "Packages/WeekFitPlanner" */,
\t\t\t\tA10000072FB2403E006A4D25 /* XCLocalSwiftPackageReference "Packages/WeekFitHealthKit" */,
\t\t\t\tF10000012FB2403E006A4D30 /* XCRemoteSwiftPackageReference "firebase-ios-sdk" */,
\t\t\t);""",
    """\t\t\tpackageReferences = (
\t\t\t\tA10000012FB2403E006A4D20 /* XCLocalSwiftPackageReference "Packages/WeekFitWorkoutMetrics" */,
\t\t\t\tA10000032FB2403E006A4D21 /* XCLocalSwiftPackageReference "Packages/WeekFitCoachCore" */,
\t\t\t\tA10000052FB2403E006A4D23 /* XCLocalSwiftPackageReference "Packages/WeekFitPlanner" */,
\t\t\t\tA10000072FB2403E006A4D25 /* XCLocalSwiftPackageReference "Packages/WeekFitHealthKit" */,
\t\t\t\tW10000092FB2403E006A4D40 /* XCLocalSwiftPackageReference "Packages/WeekFitWidgetShared" */,
\t\t\t\tF10000012FB2403E006A4D30 /* XCRemoteSwiftPackageReference "firebase-ios-sdk" */,
\t\t\t);""",
)

text = text.replace(
    """\t\t\ttargets = (
\t\t\t\t55E7BBE42FB2403E006A4D20 /* WeekFit */,
\t\t\t\t55E7BBF12FB24040006A4D20 /* WeekFitTests */,
\t\t\t\t55E7BBFB2FB24040006A4D20 /* WeekFitUITests */,
\t\t\t);""",
    """\t\t\ttargets = (
\t\t\t\t55E7BBE42FB2403E006A4D20 /* WeekFit */,
\t\t\t\tW10000302FB2403E006A4D40 /* WeekFitWidget */,
\t\t\t\t55E7BBF12FB24040006A4D20 /* WeekFitTests */,
\t\t\t\t55E7BBFB2FB24040006A4D20 /* WeekFitUITests */,
\t\t\t);""",
)

# --- Resources / Sources phases for widget ---
text = text.replace(
    "/* End PBXResourcesBuildPhase section */",
    """\t\tW10000B02FB2403E006A4D40 /* Resources */ = {
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
/* End PBXResourcesBuildPhase section */""",
)

text = text.replace(
    "/* End PBXSourcesBuildPhase section */",
    """\t\tW10000A02FB2403E006A4D40 /* Sources */ = {
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
/* End PBXSourcesBuildPhase section */""",
)

text = text.replace(
    "/* End PBXTargetDependency section */",
    """\t\tW10000802FB2403E006A4D40 /* PBXTargetDependency */ = {
\t\t\tisa = PBXTargetDependency;
\t\t\ttarget = W10000302FB2403E006A4D40 /* WeekFitWidget */;
\t\t\ttargetProxy = W10000202FB2403E006A4D40 /* PBXContainerItemProxy */;
\t\t};
/* End PBXTargetDependency section */""",
)

# --- Build configurations for widget ---
widget_configs = """
\t\tW10000C02FB2403E006A4D40 /* Debug */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {
\t\t\t\tCODE_SIGN_ENTITLEMENTS = WeekFitWidget/WeekFitWidget.entitlements;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 19;
\t\t\t\tDEVELOPMENT_TEAM = 7R6347XPK2;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tINFOPLIST_FILE = WeekFitWidget/Info.plist;
\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = WeekFit;
\t\t\t\tINFOPLIST_KEY_NSHumanReadableCopyright = "";
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 18.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t\t"@executable_path/../../Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.2.2;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.weekfit.app.widget;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSKIP_INSTALL = YES;
\t\t\t\tSUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
\t\t\t\tSUPPORTS_MACCATALYST = NO;
\t\t\t\tSUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = NO;
\t\t\t\tSUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD = NO;
\t\t\t\tSWIFT_APPROACHABLE_CONCURRENCY = YES;
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = 1;
\t\t\t};
\t\t\tname = Debug;
\t\t};
\t\tW10000D02FB2403E006A4D40 /* Release */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {
\t\t\t\tCODE_SIGN_ENTITLEMENTS = WeekFitWidget/WeekFitWidget.entitlements;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 19;
\t\t\t\tDEVELOPMENT_TEAM = 7R6347XPK2;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tINFOPLIST_FILE = WeekFitWidget/Info.plist;
\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = WeekFit;
\t\t\t\tINFOPLIST_KEY_NSHumanReadableCopyright = "";
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 18.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t\t"@executable_path/../../Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.2.2;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.weekfit.app.widget;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSKIP_INSTALL = YES;
\t\t\t\tSUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
\t\t\t\tSUPPORTS_MACCATALYST = NO;
\t\t\t\tSUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = NO;
\t\t\t\tSUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD = NO;
\t\t\t\tSWIFT_APPROACHABLE_CONCURRENCY = YES;
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = 1;
\t\t\t};
\t\t\tname = Release;
\t\t};
"""

text = text.replace(
    "/* End XCBuildConfiguration section */",
    widget_configs + "/* End XCBuildConfiguration section */",
)

text = text.replace(
    "/* End XCConfigurationList section */",
    """\t\tW10000902FB2403E006A4D40 /* Build configuration list for PBXNativeTarget "WeekFitWidget" */ = {
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\tW10000C02FB2403E006A4D40 /* Debug */,
\t\t\t\tW10000D02FB2403E006A4D40 /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t};
/* End XCConfigurationList section */""",
)

text = text.replace(
    "/* End XCLocalSwiftPackageReference section */",
    """\t\tW10000092FB2403E006A4D40 /* XCLocalSwiftPackageReference "Packages/WeekFitWidgetShared" */ = {
\t\t\tisa = XCLocalSwiftPackageReference;
\t\t\trelativePath = Packages/WeekFitWidgetShared;
\t\t};
/* End XCLocalSwiftPackageReference section */""",
)

text = text.replace(
    "/* End XCSwiftPackageProductDependency section */",
    """\t\tW100000A2FB2403E006A4D40 /* WeekFitWidgetShared */ = {
\t\t\tisa = XCSwiftPackageProductDependency;
\t\t\tpackage = W10000092FB2403E006A4D40 /* XCLocalSwiftPackageReference "Packages/WeekFitWidgetShared" */;
\t\t\tproductName = WeekFitWidgetShared;
\t\t};
\t\tW100000B2FB2403E006A4D40 /* WeekFitWidgetShared */ = {
\t\t\tisa = XCSwiftPackageProductDependency;
\t\t\tpackage = W10000092FB2403E006A4D40 /* XCLocalSwiftPackageReference "Packages/WeekFitWidgetShared" */;
\t\t\tproductName = WeekFitWidgetShared;
\t\t};
/* End XCSwiftPackageProductDependency section */""",
)

PBX.write_text(text)
print("patched ok")
