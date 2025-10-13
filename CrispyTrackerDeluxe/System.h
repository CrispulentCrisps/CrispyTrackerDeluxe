#pragma once

//Overarching system handling, handles PC specific components

#include "Tracker.h"

class System
{
public:
	Tracker tracker;

	bool IsRunning = true;

	void Init();
	void Run();
	void Draw();
};

