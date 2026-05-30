import fs from 'node:fs';
import path from 'node:path';

const configPath = path.resolve('ios/App/App/capacitor.config.json');
const capSpmPackagePath = path.resolve('ios/App/CapApp-SPM/Package.swift');
const pluginClasses = ['BeaconNativePlugin', 'App.BeaconNativePlugin'];

if (!fs.existsSync(configPath)) {
  console.warn(`[ensure_ios_plugin_registration] Skipped: ${configPath} does not exist`);
  process.exit(0);
}

const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
const packageClassList = Array.isArray(config.packageClassList) ? config.packageClassList : [];

let changed = false;
for (const pluginClass of pluginClasses) {
  if (packageClassList.includes(pluginClass)) {
    continue;
  }
  packageClassList.push(pluginClass);
  config.packageClassList = packageClassList;
  changed = true;
}

if (changed) {
  fs.writeFileSync(configPath, `${JSON.stringify(config, null, '\t')}\n`);
  console.log(`[ensure_ios_plugin_registration] Added Beacon native plugin classes to packageClassList`);
} else {
  console.log(`[ensure_ios_plugin_registration] Beacon native plugin classes already present`);
}

if (fs.existsSync(capSpmPackagePath)) {
  const packageSwift = fs.readFileSync(capSpmPackagePath, 'utf8');
  const normalizedPackageSwift = packageSwift.replace(
    'platforms: [.iOS(.v26)]',
    'platforms: [.iOS("26.2")]',
  );

  if (normalizedPackageSwift !== packageSwift) {
    fs.writeFileSync(capSpmPackagePath, normalizedPackageSwift);
    console.log(`[ensure_ios_plugin_registration] Normalized CapApp-SPM iOS platform to 26.2`);
  }
}
