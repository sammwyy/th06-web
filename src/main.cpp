#include <SDL2/SDL.h>
#include <SDL2/SDL_mouse.h>
#include <cstdio>

#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#endif

#include "AnmManager.hpp"
#include "Chain.hpp"
#include "FileSystem.hpp"
#include "GameErrorContext.hpp"
#include "GameWindow.hpp"
#include "SoundPlayer.hpp"
#include "Stage.hpp"
#include "Supervisor.hpp"
#include "ZunResult.hpp"
#include "i18n.hpp"
#include "utils.hpp"

struct AppState
{
    i32 renderResult;
    bool finished;
};

#ifdef __EMSCRIPTEN__
static void ApplyBrowserConfigOverrides()
{
    FILE *wavFile = FileSystem::FopenUTF8("bgm/th06_01.wav", "rb");

    g_Supervisor.cfg.windowed = true;
    g_Supervisor.cfg.playSounds = 1;

    if (wavFile != NULL)
    {
        g_Supervisor.cfg.musicMode = WAV;
        std::fclose(wavFile);
    }
}
#endif

static ZunResult StartGame(AppState *state)
{
    state->renderResult = 0;
    state->finished = false;

    GameWindow::CreateGameWindow();

    g_AnmManager = new AnmManager();

    if (GameWindow::InitD3dRendering() != ZUN_SUCCESS)
    {
        g_GameErrorContext.Flush();
        return ZUN_ERROR;
    }

    g_SoundPlayer.InitializeDSound();
    Controller::GetJoystickCaps();
    Controller::ResetKeyboard();

    if (Supervisor::RegisterChain() != ZUN_SUCCESS)
    {
        return ZUN_ERROR;
    }
    if (!g_Supervisor.cfg.windowed)
    {
        SDL_ShowCursor(SDL_DISABLE);
    }

    g_GameWindow.curFrame = 0;
    return ZUN_SUCCESS;
}

static void StopGame()
{
    g_Chain.Release();
    g_SoundPlayer.Release();

    delete g_AnmManager;
    g_AnmManager = NULL;

    if (g_GfxBackend != NULL)
    {
        delete g_GfxBackend;
        g_GfxBackend = NULL;
    }
    SDL_Quit();
}

static void FinishGame(AppState *state)
{
    StopGame();

    if (state->renderResult == 2)
    {
        g_GameErrorContext.ResetContext();

        g_GameErrorContext.Log(TH_ERR_OPTION_CHANGED_RESTART);

#ifdef __EMSCRIPTEN__
        ApplyBrowserConfigOverrides();
#endif

        if (!g_Supervisor.cfg.windowed)
        {
            SDL_ShowCursor(SDL_ENABLE);
        }

        if (StartGame(state) == ZUN_SUCCESS)
        {
            return;
        }

        state->renderResult = RENDER_RESULT_EXIT_ERROR;
    }

    FileSystem::WriteDataToFile(TH_CONFIG_FILE, &g_Supervisor.cfg, sizeof(g_Supervisor.cfg));
    //    SystemParametersInfo(SPI_SETSCREENSAVEACTIVE, g_GameWindow.screenSaveActive, NULL, SPIF_SENDCHANGE);
    //    SystemParametersInfo(SPI_SETLOWPOWERACTIVE, g_GameWindow.lowPowerActive, NULL, SPIF_SENDCHANGE);
    //    SystemParametersInfo(SPI_SETPOWEROFFACTIVE, g_GameWindow.powerOffActive, NULL, SPIF_SENDCHANGE);

    SDL_ShowCursor(SDL_ENABLE);
    g_GameErrorContext.Flush();
    state->finished = true;

#ifdef __EMSCRIPTEN__
    emscripten_cancel_main_loop();
#endif
}

static void TickGame(void *arg)
{
    AppState *state = (AppState *)arg;
    SDL_Event e;

    while (SDL_PollEvent(&e))
    {
        if (e.type == SDL_QUIT)
        {
            state->renderResult = RENDER_RESULT_EXIT_SUCCESS;
            FinishGame(state);
            return;
        }
    }

    state->renderResult = g_GameWindow.Render();
    if (state->renderResult != 0)
    {
        FinishGame(state);
        return;
    }

    //        SDL_Delay(1000.0f / 60.0f);
}

int main(int argc, char *argv[])
{
    (void)argc;
    (void)argv;

    static AppState state;
    //    MSG msg;
    //    i32 waste1, waste2, waste3, waste4, waste5, waste6;

    //    if (utils::CheckForRunningGameInstance())
    //    {
    //        g_GameErrorContext.Flush();
    //
    //        return 1;
    //    }

    //    g_Supervisor.hInstance = hInstance;

    if (g_Supervisor.LoadConfig(TH_CONFIG_FILE) != ZUN_SUCCESS)
    {
        g_GameErrorContext.Flush();
        return -1;
    }

#ifdef __EMSCRIPTEN__
    ApplyBrowserConfigOverrides();
#endif

    //    if (GameWindow::InitD3dInterface())
    //    {
    //        g_GameErrorContext.Flush();
    //        return 1;
    //    }

    //    SystemParametersInfo(SPI_GETSCREENSAVEACTIVE, 0, &g_GameWindow.screenSaveActive, 0);
    //    SystemParametersInfo(SPI_GETLOWPOWERACTIVE, 0, &g_GameWindow.lowPowerActive, 0);
    //    SystemParametersInfo(SPI_GETPOWEROFFACTIVE, 0, &g_GameWindow.powerOffActive, 0);
    //    SystemParametersInfo(SPI_SETSCREENSAVEACTIVE, 0, NULL, SPIF_SENDCHANGE);
    //    SystemParametersInfo(SPI_SETLOWPOWERACTIVE, 0, NULL, SPIF_SENDCHANGE);
    //    SystemParametersInfo(SPI_SETPOWEROFFACTIVE, 0, NULL, SPIF_SENDCHANGE);

    if (StartGame(&state) != ZUN_SUCCESS)
    {
        StopGame();
        g_GameErrorContext.Flush();
        return 1;
    }

#ifdef __EMSCRIPTEN__
    emscripten_set_main_loop_arg(TickGame, &state, 0, 1);
#else
    while (!state.finished)
    {
        TickGame(&state);
    }
#endif

    //    SystemParametersInfo(SPI_SETSCREENSAVEACTIVE, g_GameWindow.screenSaveActive, NULL, SPIF_SENDCHANGE);
    //    SystemParametersInfo(SPI_SETLOWPOWERACTIVE, g_GameWindow.lowPowerActive, NULL, SPIF_SENDCHANGE);
    //    SystemParametersInfo(SPI_SETPOWEROFFACTIVE, g_GameWindow.powerOffActive, NULL, SPIF_SENDCHANGE);

    return 0;
}
