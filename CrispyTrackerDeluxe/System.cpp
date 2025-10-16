#include "System.h"

#define IMGUI_IMPLEMENTATION
#include "misc/single_file/imgui_single_file.h"
#include "backends/imgui_impl_sdl3.cpp"
#include "backends/imgui_impl_sdlrenderer3.cpp"

uint64_t OldTime = 0;
uint64_t DeltaTime = 1;

void System::Init()
{
	tracker.Init();
	InitVideo();
	IsRunning = true;
}

void System::InitVideo()
{
	SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO);
	window = SDL_CreateWindow("CrispyTrackerDeluxe", WINDOW_WIDTH, WINDOW_HEIGHT, 0);
	rend = SDL_CreateRenderer(window, NULL);
	SDL_SetRenderVSync(rend, 1);
	ImGui::CreateContext();
	ImGui_ImplSDL3_InitForSDLRenderer(window, rend);
	ImGui_ImplSDLRenderer3_Init(rend);

	ImGui::StyleColorsClassic();
}

void System::Run()
{
	while (IsRunning)
	{
		ImGui_ImplSDLRenderer3_NewFrame();
		ImGui_ImplSDL3_NewFrame();
		ImGui::NewFrame();
		SDL_Event sdlevent;
		while (SDL_PollEvent(&sdlevent))
		{
			ImGui_ImplSDL3_ProcessEvent(&sdlevent);
			if (sdlevent.type == SDL_EVENT_QUIT)
			{
				IsRunning = false;
				break;
			}
		}
		OldTime = SDL_GetPerformanceCounter();
		SDL_RenderClear(rend);
		tracker.Run();
		Draw();
		ImGui::Render();
		ImGui_ImplSDLRenderer3_RenderDrawData(ImGui::GetDrawData(), rend);
		SDL_RenderPresent(rend);
		DeltaTime = SDL_GetPerformanceCounter() - OldTime;
	}
}

void System::Draw()
{
	DrawChannels();
	DrawInstrumentList();
	DrawSampleList();
	if (InstEditorOpen) DrawInstrumentEditor();
}

void System::DrawChannels()
{
	if (ImGui::Begin("Channel view", 0, 0))
	{
		if (ImGui::BeginTable("##MainChView", CHANNEL_COUNT, TABLE_SETTINGS))
		{
			int Id = 0;
			for (int z = 0; z < CHANNEL_COUNT; z++)
			{
				ImGui::TableNextColumn();
				ImGui::SeparatorText(GetChannelname(z).c_str());
				Pattern* pat = tracker.GetCurrentPattern(z);
				if (ImGui::BeginTable(GetHexUnique(z, Id).c_str(), ROW_ITEM_LEN, TABLE_SETTINGS))
				{
					for (int x = 0; x < tracker.GetRowLen(); x++)
					{
						ImGui::TableNextRow();
						ImGui::TableNextColumn();
						if (ImGui::Selectable(GetNoteNameUnique(pat->rows[x].note, Id).c_str(), tracker.IsCursorOver(z, 0, x)));
						ImGui::TableNextColumn();
						if (ImGui::Selectable(GetHexUnique(pat->rows[x].inst, Id).c_str(), tracker.IsCursorOver(z, 1, x)));
						ImGui::TableNextColumn();
						if (ImGui::Selectable(GetHexUnique(pat->rows[x].vol, Id).c_str(), tracker.IsCursorOver(z, 2, x)));
						for (int y = 0; y < MAX_FX_COL; y++)
						{
							ImGui::TableNextColumn();
							if (ImGui::Selectable(GetHexUnique(pat->rows[x].fx[y].type, Id).c_str(), tracker.IsCursorOver(z, 3 + (y * 2), x)));
							ImGui::TableNextColumn();
							if (ImGui::Selectable(GetHexUnique(pat->rows[x].fx[y].val, Id).c_str(), tracker.IsCursorOver(z, 4 + (y * 2), x)));
						}
					} 
					ImGui::EndTable();
				}
			}
			ImGui::EndTable();
		}
	}
	ImGui::End();
}

void System::DrawInstrumentList()
{
	if (ImGui::Begin("Instrument list"))
	{
		for (int x = 0; x < tracker.GetInstLen(); x++)
		{
			std::string name = Index2String(x).c_str();
			name.append(tracker.GetInstrument(x)->name);
			if (ImGui::Selectable(name.c_str(), tracker.GetSelectedInst() == x)) {
				tracker.SetSelectedInst(x);
			}
		}
		if (ImGui::Selectable("Add new instrument +", false))
		{
			char buf[8];
			std::string newname = "Instrument: ";
			newname.append(itoa(tracker.GetInstLen(), buf, 16));
			tracker.AddNewInst(newname);
		}
		ImGui::End();
	}
}

void System::DrawInstrumentEditor()
{
	if (ImGui::Begin("Instrument Editor", &InstEditorOpen, 0))
	{
		Instrument* inst = tracker.GetCurrentInstrument();

		ImGui::Text(inst->name.c_str());

		std::string samplename = "No samples loaded";
		if (tracker.GetSampleLen() != 0)
		{
			samplename = tracker.GetCurrentSample(inst->sampleind)->name;
		}
		
		if (ImGui::BeginCombo("Selected sample", samplename.c_str())) 
		{
			for (int x = 0; x < tracker.GetSampleLen(); x++)
			{
				if (ImGui::Selectable(tracker.GetCurrentSample(x)->name.c_str(), inst->sampleind == x))
				{
					inst->sampleind = x;
				}
			}
			ImGui::EndCombo();
		}

		ImGui::Checkbox("ADSR Enable", &inst->ADSRenable);
		if (inst->ADSRenable)
		{
			ImGui::SliderInt("Attack",	&inst->attack,	0, 0x0F, "%X", 0);
			ImGui::SliderInt("Decay",	&inst->decay,	0, 0x07, "%X", 0);
			ImGui::SliderInt("Sustain", &inst->sustain, 0, 0x07, "%X", 0);
			ImGui::SliderInt("Release", &inst->release, 0, 0x1F, "%X", 0);
		}
		ImGui::SliderInt("Left volume", &inst->leftvol, 0, 0x7F, "%X", 0);
		ImGui::SliderInt("Right volume", &inst->rightvol, 0, 0x7F, "%X", 0);
		ImGui::SliderInt("Gain", &inst->gain, 0, 0x7F, "%X", 0);
		ImGui::Checkbox("Echo Enable", &inst->EchoEnable);
		ImGui::Checkbox("Noise Enable", &inst->NoiseEnable);
		ImGui::Checkbox("Pitch mod Enable", &inst->PitchModEnable);
	}
	ImGui::End();
}

void System::DrawSampleList()
{
	if (ImGui::Begin("Sample list"))
	{
		for (int x = 0; x < tracker.GetSampleLen(); x++)
		{
			std::string name = Index2String(x).c_str();
			name.append(tracker.GetCurrentSample(x)->name);
			if (ImGui::Selectable(name.c_str(), tracker.GetSelectedSample() == x)) {
				tracker.SetCurrentSample(x);
			}
		}
		if (ImGui::Selectable("Add new sample +", false))
		{
			bool issuccessful = false;
			Sample newsample = filemanager.ReadSample(&issuccessful);
			if (issuccessful) { tracker.AddSample(newsample); }
		}
		ImGui::End();
	}
}

void System::DrawSampleEditor()
{

}

std::string System::GetNoteName(int val)
{
	if (val == ROW_NULL) { return ROW_NOTE_NULL; }
	else 
	{
		char buf[3];
		char* oct = itoa(val / OCTAVE, buf, 16);
		std::string note = NoteNames[val % OCTAVE];
		note.append(oct);
		return note;
	}
}

std::string System::GetNoteNameUnique(int val, int& id)
{
	std::string out = GetNoteName(val);
	char buf[32];
	out.append("##");
	out.append(itoa(id, buf, 16));
	id++;
	return out;
}

std::string System::GetHex(int val)
{
	char buf[2];
	if (val == ROW_NULL) { return ROW_NULL_IDENT; }
	else { return itoa(val, buf, 16); }
}

std::string System::GetHexUnique(int val, int& id)
{
	std::string out = GetHex(val);
	char buf[32];
	out.append("##");
	out.append(itoa(id, buf, 16));
	id++;
	return out;
}

std::string System::GetChannelname(int ch)
{
	char buf[4];
	std::string chname = "Channel ";
	chname.append(itoa(ch, buf, 10));
	return chname;
}

std::string System::Index2String(int ind)
{
	std::string out = "";
	char buf[8];
	out.append(itoa(ind, buf, 16));
	out.append(": ");
	return out;
}

void System::Exit()
{
	ImGui_ImplSDLRenderer3_Shutdown();
	ImGui_ImplSDL3_Shutdown();
	ImGui::DestroyContext();

	SDL_DestroyRenderer(rend);
	SDL_DestroyWindow(window);
	SDL_Quit();
}
