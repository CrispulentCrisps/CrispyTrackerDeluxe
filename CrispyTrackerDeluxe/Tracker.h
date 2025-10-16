#pragma once

//Tracker functionality, handles the interaction between backend driver and frontend operations

#include "Types.h"

class Tracker
{
public:
	Module mod = { };

	Channel channels[CHANNEL_COUNT] = { };
		
	Cursor cursor;		//Track cursor

	int SubtuneInd;

	int SelectedRow;
	int SelectedOrder;
	int SelectedInst;
	int SelectedSample;

	void Init();

	void ClearModule();
	void AddSubtune();
	
	//
	//	Naming convention
	//		[Current] is a pointer to the currently selected instrument
	//		[Selected] is a the selected index into the given list
	//
	Instrument* GetInstrument(int ind);
	void SetSelectedInst(int ind);
	int GetSelectedInst();
	Instrument* AddNewInst(std::string name);

	Sample* GetCurrentSample(int ind);
	void SetCurrentSample(int ind);
	int GetSelectedSample();
	Sample* AddSample(Sample sample);

	Instrument* GetCurrentInstrument();
	Pattern* GetCurrentPattern(int chindex);
	Order* GetOrder();

	bool IsCursorOver(int x, int finex, int y);
	int GetRowLen();
	int GetInstLen();
	int GetSampleLen();

	bool Run();
};