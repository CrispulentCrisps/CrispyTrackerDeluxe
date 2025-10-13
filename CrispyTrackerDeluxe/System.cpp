#include "System.h"

clock_t OldTime = 0;
clock_t DeltaTime = 0;

void System::Init()
{
	tracker.Init();
}

void System::Run()
{
	while (IsRunning) {
		OldTime = clock();
		tracker.Run();
		DeltaTime = clock() - OldTime;
	}
}

void System::Draw()
{

}
