#include <Helix/Sample/Sample.h>

const char* helix::sample::PlatformName()
{
#if defined(HX_PLATFORM_WEB)
    return "web";
#elif defined(HX_PLATFORM_ANDROID)
    return "android";
#else
    return "linux";
#endif
}
