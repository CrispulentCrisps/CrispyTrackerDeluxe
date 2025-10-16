#pragma once

#include "Types.h"

//Used for handling the windows file dialogue
class FileManager
{
public:
	void SaveModule(Module& mod, SDL_Window* win);
	std::string LoadModule();
	std::string LoadSample();
	Sample ReadSample(bool* loadsucceed);
};

