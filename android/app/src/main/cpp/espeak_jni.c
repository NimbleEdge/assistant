#include <android/log.h>
#include <jni.h>
#include <stdlib.h>
#include <string.h>
#include "espeak_ng.h"
#include "speak_lib.h"

#define LOG_TAG "EspeakJNI"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

static int voice_initialized;

JNIEXPORT jint JNICALL
Java_dev_deliteai_assistant_domain_features_tts_espeak_EspeakManager_nativeInitialize(
    JNIEnv *env, jobject thiz, jint output, jint bufLength, jstring path, jint options)
{
  const char *p = path ? (*env)->GetStringUTFChars(env, path, NULL) : NULL;
  int r = espeak_Initialize((espeak_AUDIO_OUTPUT)output, bufLength, p, options);
  if (r > 0 && espeak_SetVoiceByName("en") == EE_OK) voice_initialized = 1;
  if (p) (*env)->ReleaseStringUTFChars(env, path, p);
  return r;
}

JNIEXPORT jstring JNICALL
Java_dev_deliteai_assistant_domain_features_tts_espeak_EspeakManager_nativeTextToPhonemes(
    JNIEnv *env, jobject thiz, jstring text, jint textMode, jint phonemeMode)
{
  if (!text) return NULL;
  const char *t = (*env)->GetStringUTFChars(env, text, NULL);
  if (!t) return NULL;
  if (!voice_initialized && espeak_SetVoiceByName("en") == EE_OK) voice_initialized = 1;
  const void *tp = t;
  const char *ph = espeak_TextToPhonemes(&tp, textMode, phonemeMode);
  jstring res = ph ? (*env)->NewStringUTF(env, ph) : NULL;
  (*env)->ReleaseStringUTFChars(env, text, t);
  return res;
}

JNIEXPORT jint JNICALL
Java_dev_deliteai_assistant_domain_features_tts_espeak_EspeakManager_nativeSetVoiceByName(
    JNIEnv *env, jobject thiz, jstring voiceName)
{
  if (!voiceName) return EE_INTERNAL_ERROR;
  const char *v = (*env)->GetStringUTFChars(env, voiceName, NULL);
  if (!v) return EE_INTERNAL_ERROR;
  int r = espeak_SetVoiceByName(v);
  voice_initialized = (r == EE_OK);
  (*env)->ReleaseStringUTFChars(env, voiceName, v);
  return r;
}
