// lmutracker.mm
// compile with:
// clang -o lmutracker lmutracker.mm -framework IOKit -framework CoreFoundation

#include <mach/mach.h>
#import <IOKit/IOKitLib.h>
#import <CoreFoundation/CoreFoundation.h>

#define AMBIENT_LIGHT_THRESHOLD 500000L

static double updateInterval = 0.1;
static io_connect_t dataPort = 0;
enum { COMMAND_MODE, VALUE_MODE, LOOP_MODE};

void printValues(CFRunLoopTimerRef timer, void* info) {
    int mode = *(int*)info;
    kern_return_t kr;
    uint32_t outputs = 2;
    uint64_t values[outputs];

    kr = IOConnectCallMethod(dataPort, 0, nil, 0, nil, 0, values, &outputs, nil, 0);
    if (kr == KERN_SUCCESS) {
        switch (mode) {
            case VALUE_MODE:
                printf("%llu %llu\n", values[0], values[1]);
            case COMMAND_MODE:
                if (values[0] > AMBIENT_LIGHT_THRESHOLD) {
                    printf("SolarizedLight"); /* print your light terminal theme */
                } else {
                    printf("SolarizedDark"); /* print your dark terminal theme */
                }
                break;
            case LOOP_MODE:
                printf("\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b%8lld %8lld", values[0], values[1]); /* prints over constantly */
                break;
        }
    } else if (kr == kIOReturnBusy) {
        printf("busy");
    } else {
        mach_error("I/O Kit error:", kr);
        exit(kr);
    }
}

int main(int argc, char** argv) {
    kern_return_t kr;
    io_service_t serviceObject;
    CFRunLoopTimerRef updateTimer;

    int mode = COMMAND_MODE;
    char opt;
    while ((opt = getopt(argc, argv, "cvl")) != -1) {
        switch (opt) {
        case 'c': mode = COMMAND_MODE; break;
        case 'v': mode = VALUE_MODE; break;
        case 'l': mode = LOOP_MODE; break;
        default:
            fprintf(stderr, "Usage: %s [-cvl]\n", argv[0]);
            exit(EXIT_FAILURE);
        }
    }


    /* open up the io for stuff */
    serviceObject = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("AppleLMUController"));
    if (!serviceObject) {
        fprintf(stderr, "failed to find ambient light sensors\n");
        exit(1);
    }
    kr = IOServiceOpen(serviceObject, mach_task_self(), 0, &dataPort);
    IOObjectRelease(serviceObject);
    if (kr != KERN_SUCCESS) {
        mach_error("IOServiceOpen:", kr);
        exit(kr);
    }

    /* loop mode for looping, otherwise print once and exit */
    if (mode == LOOP_MODE) {
        setbuf(stdout, NULL);
        printf("%8ld %8ld", 0L, 0L);
        CFRunLoopTimerContext context = CFRunLoopTimerContext();
        context.info = &mode;
        updateTimer = CFRunLoopTimerCreate(kCFAllocatorDefault,
                CFAbsoluteTimeGetCurrent() + updateInterval, updateInterval,
                0, 0, printValues, &context);
        CFRunLoopAddTimer(CFRunLoopGetCurrent(), updateTimer, kCFRunLoopDefaultMode);
        CFRunLoopRun();
        break;
    } else {
        printValues(nil, &mode);
    }

    exit(0);
}
