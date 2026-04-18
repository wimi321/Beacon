# Beacon

<div dir="rtl">

<p align="center">
  <strong>Beacon يحول الهاتف إلى أداة طوارئ وبقاء تعمل بأسلوب offline-first وتعتمد على استدلال Gemma 4 الحقيقي على الجهاز نفسه.</strong>
</p>

<p align="center">
  مستندات المستودع:
  <a href="./README.md">English</a>
  ·
  <a href="./README.zh-CN.md">简体中文</a>
  ·
  <a href="./README.zh-TW.md">繁體中文</a>
  ·
  <a href="./README.ja.md">日本語</a>
  ·
  <a href="./README.ko.md">한국어</a>
  ·
  <a href="./README.es.md">Español</a>
  ·
  <a href="./README.fr.md">Français</a>
  ·
  <a href="./README.de.md">Deutsch</a>
  ·
  <a href="./README.pt.md">Português</a>
  ·
  <a href="./README.ar.md">العربية</a>
</p>

<p align="center">
  <a href="./docs/assets/beacon-demo-hero.mp4">
    <img src="./docs/assets/beacon-demo-hero.gif" alt="Beacon README demo" width="960">
  </a>
</p>

> هذا الملف هو صفحة دخول عربية مختصرة. المرجع التقني الأكثر اكتمالاً وحداثة ما يزال هو النسخة الإنجليزية [`README.md`](./README.md).

## التنزيل

- نزّل أحدث ملف APK لنظام Android ARM64 من [GitHub Releases](https://github.com/wimi321/Beacon/releases)
- افتح `Settings & Models` عند التشغيل الأول
- نزّل `Gemma 4 E2B` أولاً كنموذج موصى به، ثم أضف `Gemma 4 E4B` إذا كان جهازك أقوى

يعتمد Beacon على مسار توزيع خفيف: ملف APK صغير أولاً، ثم تنزيل نموذج Gemma من داخل التطبيق.

## لماذا Beacon

- ذكاء اصطناعي حقيقي على الجهاز، وليس واجهة دردشة سحابية
- استرجاع دون اتصال من مصادر طبية ومصادر بقاء ميداني
- واجهة جوال مبسطة للحالات عالية التوتر وقليلة الانتباه
- دعم الكاميرا والصور المحلية
- يدعم 20 لغة للواجهة مع RTL للعربية
- ذاكرة جلسة، وميزات SOS، وربط أصلي مع البطارية والموقع والتشخيصات

## القدرات الأساسية

- إرشاد نصي للطوارئ على الجهاز
- مساعدة بصرية عبر الكاميرا أو صورة من الألبوم
- بحث في المعرفة المحلية قبل الاستدلال
- ذاكرة للمحادثة والسياق البصري
- مشاريع Android و iOS الأصلية موجودة داخل المستودع

## الوثائق

- README الرئيسي بالإنجليزية: [`README.md`](./README.md)
- README بالصينية المبسطة: [`README.zh-CN.md`](./README.zh-CN.md)
- دليل المساهمة: [`CONTRIBUTING.md`](./CONTRIBUTING.md)، [`CONTRIBUTING.zh-CN.md`](./CONTRIBUTING.zh-CN.md)
- سياسة الأمان: [`SECURITY.md`](./SECURITY.md)، [`SECURITY.zh-CN.md`](./SECURITY.zh-CN.md)
- ملاحظات التدويل: [`docs/I18N.md`](./docs/I18N.md)، [`docs/I18N.zh-CN.md`](./docs/I18N.zh-CN.md)

## البدء السريع

```bash
npm install
npm run mobile:build
npm run mobile:android
npm run mobile:ios
```

بناء APK خفيف للنشر على GitHub:

```bash
npm run mobile:android:release:github
```

## حالة المشروع

Beacon إصدار عام تمهيدي جاد وقابل للتشغيل. ليس عرضاً وهمياً، لكنه ليس بعد منتجاً طبياً نهائياً.

المتوفر حالياً:

- مشاريع Android و iOS أصلية
- مسار استدلال Gemma 4 على الجهاز
- قاعدة معرفة محلية مدمجة
- واجهة متعددة اللغات
- ذاكرة جلسة وتدفق بصري محلي

ما يزال قيد التحسين:

- التحقق على عدد أكبر من الأجهزة الحقيقية
- استقرار runtime و GPU على iOS
- الترحيل الشبكي mesh وتوسيع SOS بين الأجهزة
- التغليف النهائي الجاهز للنشر في المتاجر

</div>
