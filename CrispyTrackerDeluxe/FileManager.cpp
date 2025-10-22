#include "FileManager.h"

static const SDL_DialogFileFilter OpenSampleFilt[] = {
    { "Wave", "wav" },
    { "MP3", "mp3" },
    { "OGG", "ogg" },
    { "Bit Rate Reduced", "brr" },
};

enum FileFilters {
    f_wave,
    f_mp3,
    f_ogg,
    f_brr,
};

std::string retpath;
bool loadsuccess = true;
bool isdone;
int filtind;

static void SDLCALL OpenSampleCallback(void* userdata, const char* const* filelist, int filter)
{
    filtind = filter;
    if (!filelist) {
        SDL_Log("An error occured: %s", SDL_GetError());
        loadsuccess = false;
        isdone = true;
        return;
    }
    else if (!*filelist) {
        SDL_Log("The user did not select any file.");
        SDL_Log("Most likely, the dialog was canceled.");
        loadsuccess = false;
        isdone = true;
        return;
    }
    loadsuccess = true;
    retpath.assign(*filelist);
    isdone = true;
}

std::string FileManager::LoadSample()
{
    loadsuccess = true;
    isdone = false;
    retpath = "";
    SDL_ShowOpenFileDialog(OpenSampleCallback, NULL, NULL, OpenSampleFilt, 4, NULL, false);
    while (!isdone) {
        if (!loadsuccess) { return ""; }
        SDL_PumpEvents();
        SDL_Delay(10);
    }
    return retpath;
}

Sample FileManager::ReadSample(bool* loadsucceed)
{
    //Did the load succeed?
    std::string path = LoadSample();
    if (path == "") //Failed load
    {
        *loadsucceed = false;
        return Sample();
    }
    
    //Check if BRR file is loaded
    if (filtind == f_brr)
    {
        //Load BRR file
        assert(false);
    }

    Sample newsample = {};
    SF_INFO info = { };
    SNDFILE* infile = sf_open(path.c_str(), SFM_READ, &info);
    int count = 1;
    while (count != 0)
    {
        int samplebuffer[0x400];
        count = sf_readf_int(infile, samplebuffer, SDL_arraysize(samplebuffer) / info.channels);

        for (int x = 0; x < count * info.channels; x += info.channels)
        {
            int finalval = 0;
            for (int y = 0; y < info.channels; y++)
            {
                finalval += samplebuffer[x + y] / info.channels;
            }
            samplebuffer[x / info.channels] = finalval;
        }

        /*
        for (int x = 0; x < count; x++)
        {
            samplebuffer[x] ^= 0x80000000;

            newsample.data.push_back(samplebuffer[x]);
        }
        */
    }
    int filenamestart = path.size();
    std::string filename;

    while (filenamestart > -1 && path[filenamestart] != '\\')
    {
        filenamestart--;
    }

    newsample.name.assign(&path[filenamestart+1]);

    sf_close(infile);
    *loadsucceed = true;
    return newsample;
}