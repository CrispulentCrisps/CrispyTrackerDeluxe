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
	//		[Current] is a pointer to the currently selected item
	//		[Selected] is a the selected index into the given list
	//
	Instrument* GetInstrument(int ind);
	void SetSelectedInst(int ind);
	int GetSelectedInst();
	Instrument* AddInst(std::string name);

	std::vector<Sample>& GetSampleList();
	Sample* GetCurrentSample(int ind);
	void SetCurrentSample(int ind);
	int GetSelectedSample();
	Sample* AddSample(Sample sample);

	Order* GetCurrentOrder();
	void SetCurrentOrder(int ind);
	int GetSelectedOrder();
	Order* AddOrder(OrderAddMode mode);
	int GetCurrentOrderPatternIndex(int ch, int ordpos);
		
	Pattern* AddPattern(OrderAddMode mode);

	Instrument* GetCurrentInstrument();
	Pattern* GetCurrentPattern(int chindex);
	Cursor* GetCursor();

	void WriteNote(int val, int octaveoff = 0);
	void WritePatternVal(int val);

	void MoveCursor(int xoff, int yoff);
	void CheckCursorBounds();
	bool IsCursorOver(int x, int finex, int y);

	int GetRowLen();
	int GetInstLen();
	int GetSampleLen();
	int GetOrderLen();
	int GetPatternLen();

	bool Run();
};