import fs from 'node:fs';
import path from 'node:path';

const configPath = path.resolve('ios/App/App/capacitor.config.json');
const pluginClass = 'BeaconNativePlugin';

if (!fs.existsSync(configPath)) {
  console.warn(`[ensure_ios_plugin_registration] Skipped: ${configPath} does not exist`);
  process.exit(0);
}

const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
const packageClassList = Array.isArray(config.packageClassList) ? config.packageClassList : [];

if (!packageClassList.includes(pluginClass)) {
  packageClassList.push(pluginClass);
  config.packageClassList = packageClassList;
  fs.writeFileSync(configPath, `${JSON.stringify(config, null, '\t')}\n`);
  console.log(`[ensure_ios_plugin_registration] Added ${pluginClass} to packageClassList`);
} else {
  console.log(`[ensure_ios_plugin_registration] ${pluginClass} already present`);
}
