#include "EmulatorHandler.h"

void EmulatorHandler::InitEmu()
{
	spc = new SNES_SPC;
	filter = new SPC_Filter;
	spc->init();
	memset(&spc->m.ram.ram, 0, 0x10000);
	spc->m.cpu_regs.pc = DRIVER_START;
	spc->m.cpu_regs.a = 0;
	spc->m.cpu_regs.x = 0;
	spc->m.cpu_regs.y = 0;
	spc->m.cpu_regs.psw = 0;
	for (int x = 0; x < DRIVER_LOAD_SIZE; x++)
	{
		spc->m.ram.ram[0x0200 + x] = DriverData[x];
	}
}

AudioFormat* EmulatorHandler::RunEmu(int runtime)
{
	//Play SPC emulator
	SNES_SPC::sample_t* spcbuf = (SNES_SPC::sample_t*)malloc(2 * runtime * sizeof(SNES_SPC::sample_t));
	AudioFormat* outbuf = (AudioFormat*)malloc(2 * runtime * sizeof(AudioFormat));
	spc->play(2 * runtime, spcbuf);
	filter->run(spcbuf, 2 * runtime);

	//Convert to audio format
	for (int x = 0; x < runtime * 2; x++)
	{
		outbuf[x] = spcbuf[x] * (1 << 16);
	}
	free(spcbuf);
	return outbuf;
}

void EmulatorHandler::Sample2BRR(std::vector<Sample>& s_list)
{
	for (int z = 0; z < s_list.size(); z++)
	{
		std::vector<AudioFormat> sampledata;//Copy of sample data, can be paddd to aling to 16 sample point requirements
		u8 brrbuf[9];						//BRR Data to be added

		//Align samples to be 16 sample points large, fill any further data with 0
		sampledata = s_list[z].data;
		if (s_list[z].data.size() % 16 != 0)
		{
			for (int w = 0; w < 16 - (s_list[z].data.size() % 16); w++)
			{
				sampledata.push_back(0);
			}
		}

		//Next we convert each set of 16 sample points into BRR data
		for (int x = 0; x < sampledata.size(); x += 16)
		{
			//Construct the shift count for every sample point, find most common
			u8 samplebuf[16];
			u8 sampleshiftarray[16];
			for (int y = 0; y < 16; y++)
			{

			}
		}
	}
}

void EmulatorHandler::ExitEmu()
{
	
}
