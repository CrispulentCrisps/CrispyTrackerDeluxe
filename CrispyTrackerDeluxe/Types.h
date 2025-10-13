#pragma once

#include <ctime>

#define MAX_ROW				256
#define MAX_ORD				256
#define MAX_SUB				256
#define MAX_FX_COL			2

#define MAX_NOTE			128

#define CHANNEL_COUNT		8
#define SFX_COUNT			3

#define MAX_SUB_NAME_LEN	256
#define MAX_SUB_DESC_LEN	8192

typedef unsigned char u8;
typedef unsigned short u16;

//Header file for output music tracks
typedef struct MusicHeader {
	u8 EchoDelay;
	u8 EchoFeedback;
	u16 EchoVol;
	u8 EchoCoeff[CHANNEL_COUNT];
	u16 InitSpeed;
};

//Header file for output music tracks
typedef struct SFXHeader {
	u8 ChannelOff;
	u8 ChannelCount;
	u16 InitSpeed;
	u16 SfxStartPtr[SFX_COUNT];
};

//Values for the effects colummn
typedef struct FXCol {
	u8 type;
	u8 val;
};

//Each row entry
typedef struct Row {
	u8 note;				//Note index
	u8 inst;				//Instrument index
	u8 vol;					//Volume index
	FXCol fx[MAX_FX_COL];
};

//Set of rows, internally a series of sequence commands
typedef struct Pattern {
	Row rows[MAX_ROW];
};

//Current pattern index in a channel
typedef struct Order {
	u8 patind[CHANNEL_COUNT];	//Index into pattern memory
};

typedef struct Channel {
	Pattern* pat;
	bool enabled;
};

//Individual tunes
typedef struct Subtune {
	bool IsSfx;							//Is a SFX channel
	Order orders[MAX_ORD];				//Order data
	char name[MAX_SUB_NAME_LEN];		//Name
	char author[MAX_SUB_NAME_LEN];		//Author
	char description[MAX_SUB_NAME_LEN];	//Description
};

//Module information to be saved as a .ctf file
typedef struct Module {
	int subind;							//Current subtune
	Subtune tunes[MAX_SUB];				//Subtune list
};

//Clock functionality

extern clock_t OldTime;
extern clock_t NewTime;