A sample command-line application with an entrypoint in `bin/`, library code
in `lib/`, and example unit test in `test/`.

ios - app_name: CFBundleDisplayName
ios - bundle_name: CFBundleName

```

flutter_app_rename_tool:
  flutter:
    app_name: far_altman_flutter

  android:
    app_name: FARAltmanAndroid
    package: com.example.android

  ios:
    app_name: FARAltmaniOS
    bundle_name: FARIOS
    bundle_id:
      debug: com.example.debug.far_ios
      profile: com.example.profile.far_ios
      release: com.example.release.far_ios

  macos:
    copyright: Copyright © 2025 FAR Altman. All rights reserved.
    app_name: FARAltmanMacOS
    bundle_name: FARMacOS
    bundle_id:
      debug: com.example.debug.far_macos
      profile: com.example.profile.far_macos
      release: com.example.release.far_macos

------

flutter_app_rename_tool:
  flutter:
    app_name: far_altman_flutter

  android:
    app_name: FARAltmanAndroid
    package: com.example.android
  
  ios:
    app_name: FARAltmaniOS
    bundle_name: FARiOS
    bundle_id: com.example.far_ios

  macos:
    copyright: FARAltmanMacOS
    app_name: FARAltmanMacOS
    bundle_name: FARMacOS
    bundle_id: com.example.far_macos
```