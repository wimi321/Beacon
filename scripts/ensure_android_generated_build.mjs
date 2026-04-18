import fs from 'node:fs';
import path from 'node:path';

const buildGradlePath = path.resolve('android/capacitor-cordova-android-plugins/build.gradle');

if (!fs.existsSync(buildGradlePath)) {
  console.warn(`[ensure_android_generated_build] Skipped: ${buildGradlePath} does not exist`);
  process.exit(0);
}

const original = fs.readFileSync(buildGradlePath, 'utf8');

let next = original
  .replace(
    "classpath 'com.android.tools.build:gradle:8.13.0'",
    "classpath 'com.android.tools.build:gradle:8.13.2'",
  )
  .replace(
    /repositories\s*\{\s*google\(\)\s*mavenCentral\(\)\s*flatDir\{\s*dirs 'src\/main\/libs', 'libs'\s*\}\s*\}/m,
    `repositories {
    google()
    mavenCentral()
}`,
  )
  .replace(/\n\s*implementation fileTree\(dir: 'src\/main\/libs', include: \['\*\.jar'\]\)/, '');

if (next === original) {
  console.log('[ensure_android_generated_build] Android generated Gradle config already normalized');
  process.exit(0);
}

fs.writeFileSync(buildGradlePath, next);
console.log('[ensure_android_generated_build] Normalized capacitor-cordova-android-plugins/build.gradle');
