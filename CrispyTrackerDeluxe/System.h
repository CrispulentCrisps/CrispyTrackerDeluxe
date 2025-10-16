#pragma once

//Overarching system handling, handles PC specific components

#include "Filemanager.h"
#include "Tracker.h"

class System
{
	const std::string NoteNames[12] = {
		"C-","C#","D-","D#","E-","F-",
		"F#","G-","G#","A-","A#","B-",
	};
public:
	Tracker tracker;
	FileManager filemanager;

	SDL_Window* window;
	SDL_Renderer* rend;

	bool IsRunning = true;
	
	bool PatternEditorOpen = true;
	bool InstEditorOpen = true;

	void Init();
	void InitVideo();

	void Run();
	void Draw();
	void DrawChannels();
	void DrawInstrumentList();
	void DrawInstrumentEditor();
	void DrawSampleList();
	void DrawSampleEditor();

	std::string GetNoteName(int val);
	std::string GetNoteNameUnique(int val, int& id);	//Appends an invisible text to the end for ID conflicts
	std::string GetHex(int val);
	std::string GetHexUnique(int val, int& id);			//Appends an invisible text to the end for ID conflicts
	std::string GetChannelname(int ch);
	std::string Index2String(int ind);

	void Exit();

};

