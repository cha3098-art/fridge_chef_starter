# google_mlkit_text_recognition declares Chinese/Japanese/Devanagari script
# recognizer classes as compileOnly (see build.gradle.kts) — we only bundle
# the Korean recognizer since that's the only script the receipt scanner uses.
# R8 sees the references and errors on the missing classes without these.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
