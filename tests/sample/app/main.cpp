#include <helix/sample/sample.h>
#include <cstdio>

int main()
{
    std::printf("helix sample on %s\n", helix::sample::PlatformName());
    return 0;
}
