#pragma once

#include "resources.h"
#include "Types.h"

class EmulatorHandler
{
public:
	SNES_SPC* spc;
	SPC_Filter* filter;

	void InitEmu();

	AudioFormat* RunEmu(int runtime);

	void Sample2BRR(std::vector<Sample>& s_list);

	void ExitEmu();
};