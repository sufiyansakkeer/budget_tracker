# Keep generic type metadata used by older flutter_local_notifications/Gson
# combinations when a device upgrades from an older release.
-keepattributes Signature
-keep,allowobfuscation,allowoptimization class com.google.gson.reflect.TypeToken { *; }
-keep,allowobfuscation,allowoptimization class com.dexterous.flutterlocalnotifications.models.** { *; }