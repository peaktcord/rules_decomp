#include <SDL3/SDL.h>

#include <cstdio>

int main() {
    const int version = SDL_GetVersion();
    if (SDL_VERSIONNUM_MAJOR(version) != 3) {
        std::fprintf(stderr, "expected SDL major version 3, got %d\n", version);
        return 1;
    }
    return 0;
}
