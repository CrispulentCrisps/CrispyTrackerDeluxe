#pragma once

#define IMGUI_DEFINE_MATH_OPERATORS

#include <vector>
#include <string>

#include "sndfile.h"
#include "SDL3/SDL.h"
#include "imgui.h"
#include "backends/imgui_impl_sdl3.h"
#include "backends/imgui_impl_sdlrenderer3.h"

#define WINDOW_WIDTH		1920
#define WINDOW_HEIGHT		1080

#define MAX_ROW				256
#define MAX_ORD				256
#define MAX_PATTERNS		256
#define MAX_SUB				256
#define MAX_FX_COL			2

#define MAX_NOTE			128
#define MAX_INST			256
#define MAX_SAMPLE			64
#define MAX_SAMPLE_LEN		0xFFFFFF

#define CHANNEL_COUNT		8
#define SFX_COUNT			3

#define MAX_SUB_NAME_LEN	256
#define MAX_SUB_DESC_LEN	8192

#define ROW_NULL			0x0100
#define ROW_NULL_IDENT		".."
#define ROW_NOTE_NULL		"---"
#define ROW_ITEM_LEN		(3 + (MAX_FX_COL * 2))
#define OCTAVE				12

#define TABLE_SETTINGS		(ImGuiTableFlags_SizingStretchSame)

typedef unsigned char u8;
typedef unsigned short u16;
typedef unsigned long u32;

//Header file for output music tracks
typedef struct {
	u8 EchoDelay;
	u8 EchoFeedback;
	u16 EchoVol;
	u8 EchoCoeff[CHANNEL_COUNT];
	u16 InitSpeed;
} MusicHeader;

//Header file for output music tracks
typedef struct {
	u8 ChannelOff;
	u8 ChannelCount;
	u16 InitSpeed;
	u16 SfxStartPtr[SFX_COUNT];
} SFXHeader;

//Internal instrument flags
enum DriverInstFlags {
	DIF_ECHO =		0x01,
	DIF_NOISE =		0x02,
	DIF_PITCHMOD =	0x04,
};
//Internal instrument definition
typedef struct {
	u8 src;
	u8 adsr1;
	u8 adsr2;
	u8 gain;
	u8 flags;
} DriverInst;

//Cursor for moving around tracker
typedef struct {
	int ChX;
	int ColX;
	int ChY;
} Cursor;

//Values for the effects colummn
typedef struct {
	u16 type;
	u16 val;
} FXCol;

//Each row entry
typedef struct Row {
	u16 note;				//Note index
	u16 inst;				//Instrument index
	u16 vol;				//Volume index
	FXCol fx[MAX_FX_COL];
} Row;

//Set of rows, internally a series of sequence commands
typedef struct {
	std::vector<Row> rows;
} Pattern;

//Current pattern index in a channel
typedef struct {
	u8 patind[CHANNEL_COUNT];	//Index into pattern memory
} Order;

typedef struct {
	Pattern* pat;				//Current pattern to show
	bool enabled;				//Enabled, if disabled then darkened and no audio output
} Channel;

typedef struct {
	std::vector<u32> data;
	std::string name;
	int LoopStart;
	int LoopEnd;
	int SampleRate;
} Sample;

typedef struct {
	int sampleind;		//Sample index
	int attack;			//Attack
	int decay;			//Decay
	int sustain;		//Sustain
	int release;		//Release
	int gain;			//Gain
	int leftvol;		//Left volume
	int rightvol;		//Right volume
	int noteoff;		//Semitone note offset
	bool ADSRenable;	//ADSR flag
	bool EchoEnable;	//Enable echo in instrument
	bool NoiseEnable;	//Enable noise in instrument
	bool PitchModEnable;//Enable pitch modulation in instrument
	std::string name;	//Instrument name
} Instrument;

//Individual tunes
typedef struct {
	std::vector<Order> orders;	//Order data
	std::string name;			//Name
	std::string author;			//Author
	std::string description;	//Description
	std::vector<Pattern> pats;	//Stored patterns
	int Speed1;					//Speed val 1
	int Speed2;					//Speed val 2
	int PatternLen;				//Length of all rows in
	bool IsSfx;					//Is a SFX channel
} Subtune;

//Module information to be saved as a .ctf file
typedef struct {
	std::vector<Subtune> tunes;		//Subtune list
	std::vector<Instrument> inst;	//Instrument list
	std::vector<Sample> samples;	//Sample list
} Module;

//Clock functionality
extern uint64_t OldTime;
extern uint64_t NewTime;