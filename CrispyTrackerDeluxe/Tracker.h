#pragma once

//Tracker functionality, handles the interaction between backend driver and frontend operations

#include "Types.h"

class Tracker
{
public:
	Module mod = { };

	Channel channels[CHANNEL_COUNT] = { };

	void Init();
	bool Run();
};