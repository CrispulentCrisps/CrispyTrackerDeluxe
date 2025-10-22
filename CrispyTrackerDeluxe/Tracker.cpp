#include "Tracker.h"

void Tracker::Init()
{
	ClearModule();
}

//Initialises the input module to a clear state
void Tracker::ClearModule()
{
	mod.inst.clear();
	mod.samples.clear();
	mod.tunes.clear();
	SubtuneInd = 0;
	AddSubtune();
}

void Tracker::AddSubtune()
{
	Subtune newsub;
	newsub.author = "";
	newsub.name = "";
	newsub.description = "";

	Pattern newpat;
	memset(&newpat, ROW_NULL, sizeof(Pattern));
	for (int i = 0; i < CHANNEL_COUNT; i++)	{ newsub.pats.push_back(newpat); }
	
	newsub.orders.clear();
	Order ord = { };
	newsub.orders.push_back(ord);
	//Set new order list
	for (int x = 0; x < CHANNEL_COUNT; x++) { newsub.orders[0].patind[x] = x; }
	newsub.Speed1 = 6;
	newsub.Speed2 = 6;
	newsub.PatternLen = 64;
	newsub.IsSfx = false;
	
	Row newrow;
	newrow.note = ROW_NULL;
	newrow.vol = ROW_NULL;
	newrow.inst = ROW_NULL;
	for (int x = 0; x < MAX_FX_COL; x++)
	{
		newrow.fx[x].type = ROW_NULL;
		newrow.fx[x].val = ROW_NULL;
	}

	for (int x = 0; x < CHANNEL_COUNT; x++)
	{
		for (int y = 0; y < newsub.PatternLen; y++)
		{
			newsub.pats[x].rows.push_back(newrow);
		}
	}
	AddInst("Instrument 0");

	mod.tunes.push_back(newsub);
}

Instrument* Tracker::GetInstrument(int ind)
{
	ind = fmin(ind, mod.inst.size());
	return &mod.inst[ind];
}

void Tracker::SetSelectedInst(int ind)
{
	assert(ind < mod.inst.size());
	SelectedInst = ind;
}

int Tracker::GetSelectedInst()
{
	return SelectedInst;
}

Instrument* Tracker::AddInst(std::string name)
{
	Instrument newinst;
	newinst.ADSRenable = false;
	newinst.EchoEnable = false;
	newinst.NoiseEnable = false;
	newinst.PitchModEnable = false;
	newinst.attack = 0;
	newinst.decay = 0;
	newinst.sustain = 0;
	newinst.release = 0;
	newinst.gain = 0x7F;
	newinst.leftvol = 0x7F;
	newinst.rightvol = 0x7F;
	newinst.noteoff = 0;
	newinst.sampleind = 0;
	newinst.name = name;
	mod.inst.push_back(newinst);
	return &mod.inst[mod.inst.size() - 1];
}

std::vector<Sample>& Tracker::GetSampleList()
{
	return mod.samples;
}

Sample* Tracker::GetCurrentSample(int ind)
{
	assert(ind < mod.samples.size());
	return &mod.samples[ind];
}

void Tracker::SetCurrentSample(int ind)
{
	assert(ind < mod.samples.size());
	SelectedSample = ind;
}

int Tracker::GetSelectedSample() 
{
	assert(SelectedSample < mod.samples.size());
	return SelectedSample;
}
Sample* Tracker::AddSample(Sample sample)
{
	assert(mod.samples.size() < MAX_SAMPLE);
	mod.samples.push_back(sample);
	return &mod.samples[mod.samples.size()-1];
}

Order* Tracker::GetCurrentOrder() {
	return &mod.tunes[SubtuneInd].orders[SelectedOrder];
}

void Tracker::SetCurrentOrder(int ind) 
{
	assert(ind >= 0 && SelectedOrder < mod.tunes[SubtuneInd].orders.size());
	SelectedOrder = ind;
}

int Tracker::GetSelectedOrder() 
{
	return SelectedOrder;
}

Order* Tracker::AddOrder(OrderAddMode mode)
{
	Order ord = { };
	Pattern newpat = { };
	int patsize = mod.tunes[SubtuneInd].pats.size() - 1;
	if (mode == ORD_NEW)
	{
		for (int x = 0; x < CHANNEL_COUNT; x++)
		{
			AddPattern(mode);
			ord.patind[x] = GetPatternLen() - 1;
		}
	}
	mod.tunes[SubtuneInd].orders.push_back(ord);
	
	return &ord;
}

int Tracker::GetCurrentOrderPatternIndex(int ch, int ordpos)
{
	return mod.tunes[SubtuneInd].orders[ordpos].patind[ch];
}

Pattern* Tracker::AddPattern(OrderAddMode mode)
{
	assert(mod.tunes[SubtuneInd].pats.size() < 256);
	Pattern newpat = {};
	newpat.rows.resize(mod.tunes[SubtuneInd].PatternLen);
	for (int x = 0; x < mod.tunes[SubtuneInd].PatternLen; x++)
	{
		newpat.rows[x].note = ROW_NULL;
		newpat.rows[x].vol = ROW_NULL;
		newpat.rows[x].inst = ROW_NULL;
		for (int y = 0; y < MAX_FX_COL; y++)
		{
			newpat.rows[x].fx[y].type = ROW_NULL;
			newpat.rows[x].fx[y].val = ROW_NULL;
		}
	}
	if (mode == ORD_NEW)
	{
		mod.tunes[SubtuneInd].pats.push_back(newpat);
	}

	return &mod.tunes[SubtuneInd].pats[mod.tunes[SubtuneInd].pats.size()-1];
}

Instrument* Tracker::GetCurrentInstrument()
{
	assert(SelectedInst < mod.inst.size());
	return &mod.inst[SelectedInst];
}

Pattern* Tracker::GetCurrentPattern(int chindex)
{
	assert(channels[chindex].pat != nullptr);
	return channels[chindex].pat;
}

int Tracker::GetSampleLen()
{
	return mod.samples.size();
}

int Tracker::GetOrderLen()
{
	return mod.tunes[SubtuneInd].orders.size();
}

bool Tracker::IsCursorOver(int x, int finex, int y)
{
	return (cursor.ChX == x) && (cursor.ColX == finex) && (cursor.ChY == y);
}

int Tracker::GetRowLen()
{
	return mod.tunes[SubtuneInd].PatternLen;
}

int Tracker::GetInstLen()
{
	return mod.inst.size();
}

void Tracker::WritePatternVal(int val)
{

}

void Tracker::WriteNote(int val, int octaveoff)
{
	channels[cursor.ChX].pat->rows[cursor.ChY].note = val + (octaveoff * OCTAVE);
	channels[cursor.ChX].pat->rows[cursor.ChY].inst = SelectedInst;
}

void Tracker::MoveCursor(int xoff, int yoff)
{
	cursor.ColX += xoff;
	cursor.ChY += yoff;

	CheckCursorBounds();
}

Cursor* Tracker::GetCursor()
{
	return &cursor;
}

void Tracker::CheckCursorBounds()
{
	if (cursor.ColX >= ROW_ITEM_LEN)
	{
		cursor.ColX %= ROW_ITEM_LEN;
		cursor.ChX++;
	}
	else if (cursor.ColX < 0)
	{
		cursor.ColX = abs(cursor.ColX) % ROW_ITEM_LEN;
		cursor.ChX--;
	}

	assert(cursor.ChX > -1 && cursor.ChX < CHANNEL_COUNT);

	cursor.ChY = fmax(0, cursor.ChY);
	cursor.ChY = fmin(mod.tunes[SubtuneInd].PatternLen, cursor.ChY);

}

int Tracker::GetPatternLen() 
{
	return mod.tunes[SubtuneInd].pats.size();
}

bool Tracker::Run()
{
	Subtune* CurrentSub = &mod.tunes[SubtuneInd];
	for (int x = 0; x < CHANNEL_COUNT; x++)
	{
		channels[x].pat = &CurrentSub->pats[CurrentSub->orders[SelectedOrder].patind[x]];
	}

	return true;
}
