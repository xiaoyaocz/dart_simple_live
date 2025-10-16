#Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class de.prosiebensat1digital.** { *; }

# Fix missing Play Core classes from Flutter embedding
-dontwarn com.google.android.play.**
-keep class com.google.android.play.** { *; }

# Keep Flutter deferred component manager
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }