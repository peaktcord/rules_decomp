#include <SDL3/SDL.h>

#include <cstdio>

static_assert(sizeof(void *) == DECOMP_EXPECTED_POINTER_BYTES,
              "compiler architecture must match the SDL target platform");

int main() {
    const int version = SDL_GetVersion();
    if (SDL_VERSIONNUM_MAJOR(version) != 3) {
        std::fprintf(stderr, "expected SDL major version 3, got %d\n", version);
        return 1;
    }
    return 0;
}
