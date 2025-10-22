#pragma once

//Overarching system handling, handles PC specific components

#include "EmulatorHandler.h"
#include "Filemanager.h"
#include "Tracker.h"

class System
{
	const std::string NoteNames[12] = {
		"C-","C#","D-","D#","E-","F-",
		"F#","G-","G#","A-","A#","B-",
	};

	const SDL_Keycode LowNoteInput[MAX_INPUT_NOTE] = {
		SDLK_Z,			SDLK_S,			SDLK_X,			SDLK_D,
		SDLK_C,			SDLK_V,			SDLK_G,			SDLK_B,
		SDLK_H,			SDLK_N,			SDLK_J,			SDLK_M,
		SDLK_COMMA,		SDLK_L,			SDLK_PERIOD,	SDLK_SEMICOLON,
	};

	const SDL_Keycode HighNoteInput[MAX_INPUT_NOTE] = {
		SDLK_Q,			SDLK_2,			SDLK_W,			SDLK_3,
		SDLK_E,			SDLK_R,			SDLK_5,			SDLK_T,
		SDLK_6,			SDLK_Y,			SDLK_7,			SDLK_U,
		SDLK_I,			SDLK_9,			SDLK_O,			SDLK_0,
	};

public:
	Tracker tracker;
	FileManager filemanager;
	EmulatorHandler emu;

	SDL_Window* window;
	SDL_Renderer* rend;

	SDL_Event sdlevent;
	std::map<SDL_Keycode, bool> keyscur;	//Array of keys pressed down
	std::map<SDL_Keycode, bool> keysprev;	//Array of keys pressed down
	SDL_AudioStream* stream;
	const SDL_AudioSpec specs = {
		SDL_AUDIO_FORMAT,
		AUDIO_CHANNELS,
		AUDIO_RATE,
	};

	int Octave = 4;
	int Step = 1;

	bool IsRunning = true;
	
	bool InstEditorOpen = false;

	void Init();
	void InitVideo();
	void InitAudio();

	void Run();

	void UpdateAudio();

	void CheckForNoteInput();

	void Draw();
	void DrawChannels();
	void DrawInstrumentList();
	void DrawInstrumentEditor();
	void DrawSampleList();
	void DrawSampleEditor();
	void DrawOrders();

	std::string GetNoteName(int val);
	std::string GetNoteNameUnique(int val, int& id);	//Appends an invisible text to the end for ID conflicts
	std::string GetHex(int val);
	std::string GetHexUnique(int val, int& id);			//Appends an invisible text to the end for ID conflicts
	std::string GetChannelname(int ch);
	std::string Index2String(int ind);

	bool GetKey(SDL_Keycode key);

	void Exit();

};

