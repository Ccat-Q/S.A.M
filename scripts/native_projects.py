"""Generate standard native shells in CI, retaining all application source.

The pinned Flutter generator owns boilerplate. Native policy is versioned here;
generated projects are included in the artifact so releases are inspectable.
"""
import pathlib
import re
import subprocess

root = pathlib.Path(__file__).resolve().parents[1]
client = root / "client"
subprocess.run(["flutter", "create", "--platforms=ios,android", "--org=dev.ccatq",
                "--project-name=sam_client", "--empty", "."], cwd=client, check=True)
project = client / "ios/Runner.xcodeproj/project.pbxproj"
text = project.read_text()
text = re.sub(r"IPHONEOS_DEPLOYMENT_TARGET = [\d.]+;", "IPHONEOS_DEPLOYMENT_TARGET = 16.0;", text)
project.write_text(text)
plist = client / "ios/Runner/Info.plist"
import plistlib
data = plistlib.loads(plist.read_bytes())
data["CFBundleDisplayName"] = "S.A.M."
data["NSAppTransportSecurity"] = {"NSAllowsLocalNetworking": True}
data["UISupportedInterfaceOrientations"] = ["UIInterfaceOrientationPortrait", "UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight"]
plist.write_bytes(plistlib.dumps(data))
# Password sessions reside in Keychain. No shared developer credentials are embedded.
entitlements = client / "ios/Runner/Runner.entitlements"
entitlements.write_bytes(plistlib.dumps({"keychain-access-groups": ["$(AppIdentifierPrefix)$(PRODUCT_BUNDLE_IDENTIFIER)"]}))
text = project.read_text().replace("INFOPLIST_FILE = Runner/Info.plist;", "INFOPLIST_FILE = Runner/Info.plist;\n\t\t\t\tCODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;")
project.write_text(text)
podfile = client / "ios/Podfile"
if podfile.exists():
    text = podfile.read_text()
    text = re.sub(r"#?\s*platform :ios, '[\d.]+'", "platform :ios, '16.0'", text)
    text = text.replace("flutter_additional_ios_build_settings(target)", "flutter_additional_ios_build_settings(target)\n    target.build_configurations.each { |config| config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0' }")
    podfile.write_text(text)
manifest = client / "android/app/src/main/AndroidManifest.xml"
text = manifest.read_text().replace('<application', '<uses-permission android:name="android.permission.INTERNET"/>\n    <application', 1)
manifest.write_text(text)
