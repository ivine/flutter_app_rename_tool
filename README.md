A sample command-line application with an entrypoint in `bin/`, library code
in `lib/`, and example unit test in `test/`.

```

flutter_app_rename:
  flutter:
    app_name: far_altman_flutter

  ios:
    app_name: FARAltmanIOS
    bundle_identifier:
      debug: com.example.app_debug
      profile: com.example.app_profile
      release: com.example.app_release

  android:
    app_name: FARAltmanAndroid
    package: com.example.android

------

flutter_app_rename:
  flutter:
    app_name: far_altman_flutter

  ios:
    app_name: FARAltmanIOS
    bundle_identifier: com.example.app_debug

  android:
    app_name: FARAltmanAndroid
    package: com.example.android
```