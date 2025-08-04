#ifndef SPEAK_LIB_H
#define SPEAK_LIB_H
/***************************************************************************
 *   Copyright (C) 2005 to 2012 by Jonathan Duddington                     *
 *   email: jonsd@users.sourceforge.net                                    *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 3 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License for more details.                          *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   along with this program; if not, see:                                 *
 *               <http://www.gnu.org/licenses/>.                           *
 ***************************************************************************/


/*************************************************************/
/* This is the header file for the library version of espeak-ng-data */
/*                                                           */
/*************************************************************/

#include <stdio.h>
#include <stddef.h>

#if defined(_WIN32) || defined(_WIN64)
#ifdef LIBESPEAK_NG_EXPORT
#define ESPEAK_API __declspec(dllexport)
#else
#define ESPEAK_API __declspec(dllimport)
#endif
#else
#define ESPEAK_API
#endif

#define ESPEAK_API_REVISION  12

// values for 'value' in espeak_SetParameter(espeakRATE, value, 0), nominally in words-per-minute
#define espeakRATE_MINIMUM  80
#define espeakRATE_MAXIMUM  450
#define espeakRATE_NORMAL   175


typedef enum {
    espeakEVENT_LIST_TERMINATED = 0, // Retrieval mode: terminates the event list.
    espeakEVENT_WORD = 1,            // Start of word
    espeakEVENT_SENTENCE = 2,        // Start of sentence
    espeakEVENT_MARK = 3,            // Mark
    espeakEVENT_PLAY = 4,            // Audio element
    espeakEVENT_END = 5,             // End of sentence or clause
    espeakEVENT_MSG_TERMINATED = 6,  // End of message
    espeakEVENT_PHONEME = 7,         // Phoneme, if enabled in espeak_Initialize()
    espeakEVENT_SAMPLERATE = 8       // Set sample rate
} espeak_EVENT_TYPE;



typedef struct {
    espeak_EVENT_TYPE type;
    unsigned int unique_identifier; // message identifier (or 0 for key or character)
    int text_position;    // the number of characters from the start of the text
    int length;           // word length, in characters (for espeakEVENT_WORD)
    int audio_position;   // the time in mS within the generated speech output data
    int sample;           // sample id (internal use)
    void* user_data;      // pointer supplied by the calling program
    union {
        int number;        // used for WORD and SENTENCE events.
        const char *name;  // used for MARK and PLAY events.  UTF8 string
        char string[8];    // used for phoneme names (UTF8). Terminated by a zero byte unless the name needs the full 8 bytes.
    } id;
} espeak_EVENT;

typedef enum {
    POS_CHARACTER = 1,
    POS_WORD,
    POS_SENTENCE
} espeak_POSITION_TYPE;


typedef enum {
    /* PLAYBACK mode: plays the audio data, supplies events to the calling program*/
    AUDIO_OUTPUT_PLAYBACK,

    /* RETRIEVAL mode: supplies audio data and events to the calling program */
    AUDIO_OUTPUT_RETRIEVAL,

    /* SYNCHRONOUS mode: as RETRIEVAL but doesn't return until synthesis is completed */
    AUDIO_OUTPUT_SYNCHRONOUS,

    /* Synchronous playback */
    AUDIO_OUTPUT_SYNCH_PLAYBACK

} espeak_AUDIO_OUTPUT;


typedef enum {
    EE_OK=0,
    EE_INTERNAL_ERROR=-1,
    EE_BUFFER_FULL=1,
    EE_NOT_FOUND=2
} espeak_ERROR;

#define espeakINITIALIZE_PHONEME_EVENTS 0x0001
#define espeakINITIALIZE_PHONEME_IPA   0x0002
#define espeakINITIALIZE_DONT_EXIT     0x8000

#ifdef __cplusplus
extern "C"
#endif
ESPEAK_API int espeak_Initialize(espeak_AUDIO_OUTPUT output, int buflength, const char *path, int options);

typedef int (t_espeak_callback)(short*, int, espeak_EVENT*);

#ifdef __cplusplus
extern "C"
#endif
ESPEAK_API void espeak_SetSynthCallback(t_espeak_callback* SynthCallback);

#ifdef __cplusplus
extern "C"
#endif
ESPEAK_API void espeak_SetUriCallback(int (*UriCallback)(int, const char*, const char*));

#ifdef __cplusplus
extern "C"
#endif
ESPEAK_API void espeak_SetPhonemeCallback(int (*PhonemeCallback)(const char *));


/********************/
/*    Synthesis     */
/********************/


#define espeakCHARS_AUTO   0
#define espeakCHARS_UTF8   1
#define espeakCHARS_8BIT   2
#define espeakCHARS_WCHAR  3
#define espeakCHARS_16BIT  4

#define espeakSSML        0x10
#define espeakPHONEMES    0x100
#define espeakENDPAUSE    0x1000
#define espeakKEEP_NAMEDATA 0x2000

#ifdef __cplusplus
extern "C"
#endif
ESPEAK_API espeak_ERROR espeak_Synth(const void *text,
                                     size_t size,
                                     unsigned int position,
                                     espeak_POSITION_TYPE position_type,
                                     unsigned int end_position,
                                     unsigned int flags,
                                     unsigned int* unique_identifier,
                                     void* user_data);

#ifdef __cplusplus
extern "C"
#endif
ESPEAK_API espeak_ERROR espeak_Synth_Mark(const void *text,
                                          size_t size,
                                          const char *index_mark,
                                          unsigned int end_position,
                                          unsigned int flags,
                                          unsigned int* unique_identifier,
                                          void* user_data);

#ifdef __cplusplus
extern "C"
#endif
ESPEAK_API espeak_ERROR espeak_Key(const char *key_name);

#ifdef __cplusplus
extern "C"
#endif
ESPEAK_API espeak_ERROR espeak_Char(wchar_t character);

/***********************/
/*  Speech Parameters  */
/***********************/

typedef enum {
    espeakSILENCE=0, /* internal use */
    espeakRATE=1,
    espeakVOLUME=2,
    espeakPITCH=3,
    espeakRANGE=4,
    espeakPUNCTUATION=5,
    espeakCAPITALS=6,
    espeakWORDGAP=7,
    espeakOPTIONS=8,   // reserved for misc. options.  not yet used
    espeakINTONATION=9,
    espeakSSML_BREAK_MUL=10,

    espeakRESERVED2=11,
    espeakEMPHASIS,   /* internal use */
    espeakLINELENGTH, /* internal use */
    espeakVOICETYPE,  // internal, 1=mbrola
    N_SPEECH_PARAM    /* last enum */
} espeak_PARAMETER;

typedef enum {
    espeakPUNCT_NONE=0,
    espeakPUNCT_ALL=1,
    espeakPUNCT_SOME=2
} espeak_PUNCT_TYPE;

#ifdef __cplusplus
extern "C"
#endif
ESPEAK_API espeak_ERROR espeak_SetParameter(espeak_PARAMETER parameter, int value, int relative);

#ifdef __cplusplus
extern "C"
#endif
ESPEAK_API int espeak_GetParameter(espeak_PARAMETER parameter, int current);

#ifdef __cplusplus
extern "C"
#endif
ESPEAK_API espeak_ERROR espeak_SetPunctuationList(const wchar_t *punctlist);

#define espeakPHONEMES_SHOW    0x01
#define espeakPHONEMES_IPA     0x02
#define espeakPHONEMES_TRACE   0x08
#define espeakPHONEMES_MBROLA  0x10
#define espeakPHONEMES_TIE     0x80

#ifdef __cplusplus
extern "C"
#endif
ESPEAK_API void espeak_SetPhonemeTrace(int phonememode, FILE *stream);

#ifdef __cplusplus
extern "C"
#endif
ESPEAK_API const char *espeak_TextToPhonemes(const void **textptr, int textmode, int phonememode);

#ifdef __cplusplus
extern "C"
#endif
ESPEAK_API const char *espeak_TextToPhonemesWithTerminator(const void **textptr, int textmode, int phonememode, int *terminator);

#ifdef __cplusplus
extern "C"
#endif
ESPEAK_API void espeak_CompileDictionary(const char *path, FILE *log, int flags);

/***********************/
/*   Voice Selection   */
/***********************/

// voice table
typedef struct {
    const char *name;      // a given name for this voice. UTF8 string.
    const char *languages;       // list of pairs of (byte) priority + (string) language (and dialect qualifier)
    const char *identifier;      // the filename for this voice within espeak-ng-data-ng-data/voices
    unsigned char gender;  // 0=none 1=male, 2=female,
    unsigned char age;     // 0=not specified, or age in years
    unsigned char variant; // only used when passed as a parameter to espeak_SetVoiceByProperties
    unsigned char xx1;     // for internal use
    int score;       // for internal use
    void *spare;     // for internal use
} espeak_VOICE;

#ifdef __cplusplus
extern "C"
#endif
ESPEAK_API const espeak_VOICE **espeak_ListVoices(espeak_VOICE *voice_spec);

#ifdef __cplusplus
extern "C"
#endif
ESPEAK_API espeak_ERROR espeak_SetVoiceByFile(const char *filename);

#ifdef __cplusplus
extern "C"
#endif
ESPEAK_API espeak_ERROR espeak_SetVoiceByName(const char *name);

#ifdef __cplusplus
extern "C"
#endif
ESPEAK_API espeak_ERROR espeak_SetVoiceByProperties(espeak_VOICE *voice_spec);

#ifdef __cplusplus
extern "C"
#endif
ESPEAK_API espeak_VOICE *espeak_GetCurrentVoice(void);

#ifdef __cplusplus
extern "C"
#endif
ESPEAK_API espeak_ERROR espeak_Cancel(void);


#ifdef __cplusplus
extern "C"
#endif
ESPEAK_API int espeak_IsPlaying(void);

#ifdef __cplusplus
extern "C"
#endif
ESPEAK_API espeak_ERROR espeak_Synchronize(void);

#ifdef __cplusplus
extern "C"
#endif
ESPEAK_API espeak_ERROR espeak_Terminate(void);


#ifdef __cplusplus
extern "C"
#endif
ESPEAK_API const char *espeak_Info(const char **path_data);

#endif 
