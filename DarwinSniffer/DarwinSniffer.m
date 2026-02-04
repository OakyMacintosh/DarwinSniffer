//
//  DarwinSniffer.m
//  Hardware detection tool for macOS - OpenCore compatible
//

#import "DarwinSniffer.h"
#import <sys/sysctl.h>
#import <mach/mach.h>
#import <libkern/OSByteOrder.h>

static BOOL GetRegistryUInt32(CFTypeRef value, uint32_t *outValue) {
    if (!value || !outValue) {
        return NO;
    }

    if (CFGetTypeID(value) == CFDataGetTypeID()) {
        NSData *data = (__bridge NSData *)value;
        if (data.length >= sizeof(uint32_t)) {
            uint32_t raw = 0;
            [data getBytes:&raw length:sizeof(uint32_t)];
            *outValue = OSSwapLittleToHostInt32(raw);
            return YES;
        }
        return NO;
    }

    if (CFGetTypeID(value) == CFNumberGetTypeID()) {
        uint32_t num = 0;
        if (CFNumberGetValue((CFNumberRef)value, kCFNumberSInt32Type, &num)) {
            *outValue = num;
            return YES;
        }
    }

    return NO;
}

static BOOL GetRegistryUInt64(CFTypeRef value, uint64_t *outValue) {
    if (!value || !outValue) {
        return NO;
    }

    if (CFGetTypeID(value) == CFDataGetTypeID()) {
        NSData *data = (__bridge NSData *)value;
        if (data.length >= sizeof(uint64_t)) {
            uint64_t raw = 0;
            [data getBytes:&raw length:sizeof(uint64_t)];
            *outValue = OSSwapLittleToHostInt64(raw);
            return YES;
        }
        if (data.length >= sizeof(uint32_t)) {
            uint32_t raw32 = 0;
            [data getBytes:&raw32 length:sizeof(uint32_t)];
            *outValue = (uint64_t)OSSwapLittleToHostInt32(raw32);
            return YES;
        }
        return NO;
    }

    if (CFGetTypeID(value) == CFNumberGetTypeID()) {
        uint64_t num = 0;
        if (CFNumberGetValue((CFNumberRef)value, kCFNumberSInt64Type, &num)) {
            *outValue = num;
            return YES;
        }
    }

    return NO;
}

static NSString *DataToBestString(NSData *data) {
    if (!data || data.length == 0) {
        return @"";
    }

    NSString *utf8 = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (utf8) {
        return utf8;
    }

    const unsigned char *bytes = data.bytes;
    NSMutableString *hex = [NSMutableString stringWithCapacity:data.length * 2];
    for (NSUInteger i = 0; i < data.length; i++) {
        [hex appendFormat:@"%02X", bytes[i]];
    }
    return [hex copy];
}

static id SanitizeJSONValue(id value) {
    if (!value || value == [NSNull null]) {
        return [NSNull null];
    }

    if ([value isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *clean = [NSMutableDictionary dictionary];
        for (id key in (NSDictionary *)value) {
            id cleanKey = ([key isKindOfClass:[NSString class]]) ? key : [key description];
            id cleanVal = SanitizeJSONValue(((NSDictionary *)value)[key]);
            if (cleanVal) {
                clean[cleanKey] = cleanVal;
            }
        }
        return clean;
    }

    if ([value isKindOfClass:[NSArray class]]) {
        NSMutableArray *clean = [NSMutableArray array];
        for (id item in (NSArray *)value) {
            id cleanItem = SanitizeJSONValue(item);
            if (cleanItem) {
                [clean addObject:cleanItem];
            } else {
                [clean addObject:[NSNull null]];
            }
        }
        return clean;
    }

    if ([value isKindOfClass:[NSData class]]) {
        return DataToBestString((NSData *)value);
    }

    if ([value isKindOfClass:[NSDate class]]) {
        return [value description];
    }

    return value;
}

@implementation HardwareInfo
@end

@implementation DarwinSniffer

+ (instancetype)sharedInstance {
    static DarwinSniffer *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[DarwinSniffer alloc] init];
    });
    return instance;
}

#pragma mark - Main Detection

- (HardwareInfo *)detectHardware {
    HardwareInfo *info = [[HardwareInfo alloc] init];
    
    NSDictionary *cpuInfo = [self detectCPU];
    info.cpuBrand = cpuInfo[@"brand"];
    info.cpuModel = cpuInfo[@"model"];
    info.cpuCores = [cpuInfo[@"cores"] integerValue];
    info.cpuThreads = [cpuInfo[@"threads"] integerValue];
    info.cpuArchitecture = cpuInfo[@"architecture"];
    info.cpuFrequency = [cpuInfo[@"frequency"] doubleValue];
    
    NSDictionary *mbInfo = [self detectMotherboard];
    info.motherboardManufacturer = mbInfo[@"manufacturer"];
    info.motherboardModel = mbInfo[@"model"];
    info.biosVersion = mbInfo[@"biosVersion"];
    info.biosDate = mbInfo[@"biosDate"];
    
    info.memoryModules = [self detectMemory];
    info.totalMemory = [self getTotalMemory];
    
    info.gpuDevices = [self detectGPU];
    info.storageDevices = [self detectStorage];
    info.networkDevices = [self detectNetwork];
    info.audioDevices = [self detectAudio];
    info.usbControllers = [self detectUSB];
    
    NSDictionary *sysInfo = [self detectSystemInfo];
    info.systemModel = sysInfo[@"model"];
    info.systemSerial = sysInfo[@"serial"];
    info.systemUUID = sysInfo[@"uuid"];
    
    return info;
}

#pragma mark - CPU Detection

- (NSDictionary *)detectCPU {
    NSMutableDictionary *cpuInfo = [NSMutableDictionary dictionary];
    
    // Get CPU brand string
    char buffer[256];
    size_t size = sizeof(buffer);
    
    if (sysctlbyname("machdep.cpu.brand_string", buffer, &size, NULL, 0) == 0) {
        cpuInfo[@"brand"] = [NSString stringWithUTF8String:buffer];
    }
    
    // Get CPU model
    int cpuModel = 0;
    size = sizeof(cpuModel);
    if (sysctlbyname("machdep.cpu.model", &cpuModel, &size, NULL, 0) == 0) {
        cpuInfo[@"model"] = [NSString stringWithFormat:@"%d", cpuModel];
    }
    
    // Get core count
    int cores = 0;
    size = sizeof(cores);
    if (sysctlbyname("machdep.cpu.core_count", &cores, &size, NULL, 0) == 0) {
        cpuInfo[@"cores"] = @(cores);
    }
    
    // Get thread count
    int threads = 0;
    size = sizeof(threads);
    if (sysctlbyname("machdep.cpu.thread_count", &threads, &size, NULL, 0) == 0) {
        cpuInfo[@"threads"] = @(threads);
    }
    
    // Get CPU frequency
    uint64_t freq = 0;
    size = sizeof(freq);
    if (sysctlbyname("hw.cpufrequency", &freq, &size, NULL, 0) == 0) {
        cpuInfo[@"frequency"] = @(freq / 1000000.0); // Convert to MHz
    }
    
    // Get architecture
    size = sizeof(buffer);
    if (sysctlbyname("hw.machine", buffer, &size, NULL, 0) == 0) {
        cpuInfo[@"architecture"] = [NSString stringWithUTF8String:buffer];
    }
    
    return cpuInfo;
}

#pragma mark - Motherboard Detection

- (NSDictionary *)detectMotherboard {
    NSMutableDictionary *mbInfo = [NSMutableDictionary dictionary];
    
    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault,
                                                       IOServiceMatching("IOPlatformExpertDevice"));
    
    if (service) {
        CFTypeRef manufacturer = IORegistryEntryCreateCFProperty(service,
                                                                CFSTR("manufacturer"),
                                                                kCFAllocatorDefault, 0);
        if (manufacturer) {
            mbInfo[@"manufacturer"] = (__bridge NSString *)manufacturer;
            CFRelease(manufacturer);
        } else {
            mbInfo[@"manufacturer"] = @"Apple Inc.";
        }
        
        CFTypeRef model = IORegistryEntryCreateCFProperty(service,
                                                         CFSTR("model"),
                                                         kCFAllocatorDefault, 0);
        if (model) {
            NSData *modelData = (__bridge NSData *)model;
            mbInfo[@"model"] = [[NSString alloc] initWithData:modelData encoding:NSUTF8StringEncoding];
            CFRelease(model);
        }
        
        CFTypeRef version = IORegistryEntryCreateCFProperty(service,
                                                           CFSTR("version"),
                                                           kCFAllocatorDefault, 0);
        if (version) {
            mbInfo[@"biosVersion"] = (__bridge NSString *)version;
            CFRelease(version);
        }
        
        // Try to get board ID
        CFTypeRef boardID = IORegistryEntryCreateCFProperty(service,
                                                           CFSTR("board-id"),
                                                           kCFAllocatorDefault, 0);
        if (boardID) {
            NSData *boardData = (__bridge NSData *)boardID;
            mbInfo[@"boardID"] = [[NSString alloc] initWithData:boardData encoding:NSUTF8StringEncoding];
            CFRelease(boardID);
        }
        
        IOObjectRelease(service);
    }
    
    mbInfo[@"biosDate"] = @"N/A";
    
    return mbInfo;
}

#pragma mark - Memory Detection

- (unsigned long long)getTotalMemory {
    uint64_t memory = 0;
    size_t size = sizeof(memory);
    if (sysctlbyname("hw.memsize", &memory, &size, NULL, 0) == 0) {
        return memory;
    }
    return 0;
}

- (NSArray *)detectMemory {
    NSMutableArray *modules = [NSMutableArray array];
    
    // Get total memory
    unsigned long long totalMem = [self getTotalMemory];
    
    // Try to get memory info from SPMemoryDataType
    io_iterator_t iterator;
    kern_return_t kr = IOServiceGetMatchingServices(kIOMainPortDefault,
                                                    IOServiceMatching("IOMemoryController"),
                                                    &iterator);
    
    if (kr == KERN_SUCCESS) {
        io_service_t service;
        while ((service = IOIteratorNext(iterator))) {
            NSMutableDictionary *memModule = [NSMutableDictionary dictionary];
            
            CFTypeRef size = IORegistryEntryCreateCFProperty(service,
                                                            CFSTR("size"),
                                                            kCFAllocatorDefault, 0);
            if (size) {
                uint64_t memSize = 0;
                if (GetRegistryUInt64(size, &memSize)) {
                    memModule[@"size"] = @(memSize);
                }
                CFRelease(size);
            }
            
            CFTypeRef type = IORegistryEntryCreateCFProperty(service,
                                                            CFSTR("type"),
                                                            kCFAllocatorDefault, 0);
            if (type) {
                memModule[@"type"] = (__bridge NSString *)type;
                CFRelease(type);
            }
            
            if (memModule.count > 0) {
                [modules addObject:memModule];
            }
            
            IOObjectRelease(service);
        }
        IOObjectRelease(iterator);
    }
    
    // If we couldn't get detailed info, create a generic entry
    if (modules.count == 0 && totalMem > 0) {
        [modules addObject:@{
            @"size": @(totalMem),
            @"type": @"Unknown",
            @"manufacturer": @"Unknown"
        }];
    }
    
    return modules;
}

#pragma mark - GPU Detection

- (NSArray *)detectGPU {
    NSMutableArray *gpus = [NSMutableArray array];
    
    io_iterator_t iterator;
    kern_return_t kr = IOServiceGetMatchingServices(kIOMainPortDefault,
                                                    IOServiceMatching("IOPCIDevice"),
                                                    &iterator);
    
    if (kr == KERN_SUCCESS) {
        io_service_t service;
        while ((service = IOIteratorNext(iterator))) {
            CFTypeRef classCode = IORegistryEntryCreateCFProperty(service,
                                                                 CFSTR("class-code"),
                                                                 kCFAllocatorDefault, 0);
            
            if (classCode) {
                NSData *classData = (__bridge NSData *)classCode;
                if (classData.length >= 4) {
                    uint32_t classValue = 0;
                    [classData getBytes:&classValue length:sizeof(uint32_t)];
                    classValue = OSSwapLittleToHostInt32(classValue);
                    // Check if it's a display controller (0x03xxxx)
                    if ((classValue >> 16) == 0x03) {
                        NSMutableDictionary *gpu = [NSMutableDictionary dictionary];
                        
                        CFTypeRef model = IORegistryEntryCreateCFProperty(service,
                                                                         CFSTR("model"),
                                                                         kCFAllocatorDefault, 0);
                        if (model) {
                            NSData *modelData = (__bridge NSData *)model;
                            gpu[@"model"] = [[NSString alloc] initWithData:modelData
                                                                 encoding:NSUTF8StringEncoding];
                            CFRelease(model);
                        }
                        
                        CFTypeRef vendorID = IORegistryEntryCreateCFProperty(service,
                                                                            CFSTR("vendor-id"),
                                                                            kCFAllocatorDefault, 0);
                        if (vendorID) {
                            uint32_t vendor = 0;
                            if (GetRegistryUInt32(vendorID, &vendor)) {
                                gpu[@"vendorID"] = [NSString stringWithFormat:@"0x%04X", vendor];
                            }
                            CFRelease(vendorID);
                        }
                        
                        CFTypeRef deviceID = IORegistryEntryCreateCFProperty(service,
                                                                            CFSTR("device-id"),
                                                                            kCFAllocatorDefault, 0);
                        if (deviceID) {
                            uint32_t device = 0;
                            if (GetRegistryUInt32(deviceID, &device)) {
                                gpu[@"deviceID"] = [NSString stringWithFormat:@"0x%04X", device];
                            }
                            CFRelease(deviceID);
                        }
                        
                        // Get VRAM if available
            CFTypeRef vram = IORegistryEntryCreateCFProperty(service,
                                                                        CFSTR("VRAM,totalsize"),
                                                                        kCFAllocatorDefault, 0);
            if (vram) {
                uint64_t vramSize = 0;
                if (GetRegistryUInt64(vram, &vramSize)) {
                    gpu[@"vram"] = @(vramSize);
                }
                CFRelease(vram);
            }
                        
                        if (gpu.count > 0) {
                            [gpus addObject:gpu];
                        }
                    }
                }
                CFRelease(classCode);
            }
            
            IOObjectRelease(service);
        }
        IOObjectRelease(iterator);
    }
    
    return gpus;
}

#pragma mark - Storage Detection

- (NSArray *)detectStorage {
    NSMutableArray *storage = [NSMutableArray array];
    
    io_iterator_t iterator;
    kern_return_t kr = IOServiceGetMatchingServices(kIOMainPortDefault,
                                                    IOServiceMatching("IOBlockStorageDevice"),
                                                    &iterator);
    
    if (kr == KERN_SUCCESS) {
        io_service_t service;
        while ((service = IOIteratorNext(iterator))) {
            NSMutableDictionary *drive = [NSMutableDictionary dictionary];
            
            CFTypeRef characteristics = IORegistryEntryCreateCFProperty(service,
                                                                       CFSTR(kIOPropertyDeviceCharacteristicsKey),
                                                                       kCFAllocatorDefault, 0);
            
            if (characteristics) {
                NSDictionary *chars = (__bridge NSDictionary *)characteristics;
                
                if (chars[@"Product Name"]) {
                    drive[@"model"] = chars[@"Product Name"];
                }
                if (chars[@"Vendor Name"]) {
                    drive[@"manufacturer"] = chars[@"Vendor Name"];
                }
                if (chars[@"Medium Type"]) {
                    drive[@"type"] = chars[@"Medium Type"];
                }
                
                CFRelease(characteristics);
            }
            
            CFTypeRef size = IORegistryEntryCreateCFProperty(service,
                                                            CFSTR("Size"),
                                                            kCFAllocatorDefault, 0);
            if (size) {
                uint64_t driveSize = 0;
                if (GetRegistryUInt64(size, &driveSize)) {
                    drive[@"size"] = @(driveSize);
                }
                CFRelease(size);
            }
            
            CFTypeRef bsdName = IORegistryEntryCreateCFProperty(service,
                                                               CFSTR("BSD Name"),
                                                               kCFAllocatorDefault, 0);
            if (bsdName) {
                drive[@"bsdName"] = (__bridge NSString *)bsdName;
                CFRelease(bsdName);
            }
            
            if (drive.count > 0) {
                [storage addObject:drive];
            }
            
            IOObjectRelease(service);
        }
        IOObjectRelease(iterator);
    }
    
    return storage;
}

#pragma mark - Network Detection

- (NSArray *)detectNetwork {
    NSMutableArray *network = [NSMutableArray array];
    
    io_iterator_t iterator;
    kern_return_t kr = IOServiceGetMatchingServices(kIOMainPortDefault,
                                                    IOServiceMatching("IONetworkController"),
                                                    &iterator);
    
    if (kr == KERN_SUCCESS) {
        io_service_t service;
        while ((service = IOIteratorNext(iterator))) {
            NSMutableDictionary *netDevice = [NSMutableDictionary dictionary];
            
            CFTypeRef bsdName = IORegistryEntryCreateCFProperty(service,
                                                               CFSTR("BSD Name"),
                                                               kCFAllocatorDefault, 0);
            if (bsdName) {
                netDevice[@"interface"] = (__bridge NSString *)bsdName;
                CFRelease(bsdName);
            }
            
            CFTypeRef macAddress = IORegistryEntryCreateCFProperty(service,
                                                                  CFSTR("IOMACAddress"),
                                                                  kCFAllocatorDefault, 0);
            if (macAddress) {
                NSData *macData = (__bridge NSData *)macAddress;
                if (macData.length >= 6) {
                    const unsigned char *bytes = [macData bytes];
                    netDevice[@"macAddress"] = [NSString stringWithFormat:@"%02X:%02X:%02X:%02X:%02X:%02X",
                                              bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5]];
                }
                CFRelease(macAddress);
            }
            
            // Get vendor and device IDs
            io_service_t parent;
            if (IORegistryEntryGetParentEntry(service, kIOServicePlane, &parent) == KERN_SUCCESS) {
                CFTypeRef vendorID = IORegistryEntryCreateCFProperty(parent,
                                                                     CFSTR("vendor-id"),
                                                                     kCFAllocatorDefault, 0);
                if (vendorID) {
                    uint32_t vendor = 0;
                    if (GetRegistryUInt32(vendorID, &vendor)) {
                        netDevice[@"vendorID"] = [NSString stringWithFormat:@"0x%04X", vendor];
                    }
                    CFRelease(vendorID);
                }
                
                CFTypeRef deviceID = IORegistryEntryCreateCFProperty(parent,
                                                                     CFSTR("device-id"),
                                                                     kCFAllocatorDefault, 0);
                if (deviceID) {
                    uint32_t device = 0;
                    if (GetRegistryUInt32(deviceID, &device)) {
                        netDevice[@"deviceID"] = [NSString stringWithFormat:@"0x%04X", device];
                    }
                    CFRelease(deviceID);
                }
                
                IOObjectRelease(parent);
            }
            
            if (netDevice.count > 0) {
                [network addObject:netDevice];
            }
            
            IOObjectRelease(service);
        }
        IOObjectRelease(iterator);
    }
    
    return network;
}

#pragma mark - Audio Detection

- (NSArray *)detectAudio {
    NSMutableArray *audio = [NSMutableArray array];
    
    io_iterator_t iterator;
    kern_return_t kr = IOServiceGetMatchingServices(kIOMainPortDefault,
                                                    IOServiceMatching("IOHDACodecDevice"),
                                                    &iterator);
    
    if (kr == KERN_SUCCESS) {
        io_service_t service;
        while ((service = IOIteratorNext(iterator))) {
            NSMutableDictionary *audioDevice = [NSMutableDictionary dictionary];
            
            CFTypeRef codecID = IORegistryEntryCreateCFProperty(service,
                                                               CFSTR("IOHDACodecVendorID"),
                                                               kCFAllocatorDefault, 0);
            if (codecID) {
                audioDevice[@"codecID"] = (__bridge NSNumber *)codecID;
                CFRelease(codecID);
            }
            
            CFTypeRef codecRevision = IORegistryEntryCreateCFProperty(service,
                                                                     CFSTR("IOHDACodecRevisionID"),
                                                                     kCFAllocatorDefault, 0);
            if (codecRevision) {
                audioDevice[@"revision"] = (__bridge NSNumber *)codecRevision;
                CFRelease(codecRevision);
            }
            
            if (audioDevice.count > 0) {
                audioDevice[@"type"] = @"HDA";
                [audio addObject:audioDevice];
            }
            
            IOObjectRelease(service);
        }
        IOObjectRelease(iterator);
    }
    
    // Also check for AppleHDAController
    kr = IOServiceGetMatchingServices(kIOMainPortDefault,
                                     IOServiceMatching("AppleHDAController"),
                                     &iterator);
    
    if (kr == KERN_SUCCESS) {
        io_service_t service;
        while ((service = IOIteratorNext(iterator))) {
            NSMutableDictionary *controller = [NSMutableDictionary dictionary];
            controller[@"type"] = @"AppleHDA Controller";
            
            // Get PCI info from parent
            io_service_t parent;
            if (IORegistryEntryGetParentEntry(service, kIOServicePlane, &parent) == KERN_SUCCESS) {
                CFTypeRef vendorID = IORegistryEntryCreateCFProperty(parent,
                                                                     CFSTR("vendor-id"),
                                                                     kCFAllocatorDefault, 0);
                if (vendorID) {
                    uint32_t vendor = 0;
                    if (GetRegistryUInt32(vendorID, &vendor)) {
                        controller[@"vendorID"] = [NSString stringWithFormat:@"0x%04X", vendor];
                    }
                    CFRelease(vendorID);
                }
                
                IOObjectRelease(parent);
            }
            
            if (controller.count > 1) {
                [audio addObject:controller];
            }
            
            IOObjectRelease(service);
        }
        IOObjectRelease(iterator);
    }
    
    return audio;
}

#pragma mark - USB Detection

- (NSArray *)detectUSB {
    NSMutableArray *usb = [NSMutableArray array];
    
    io_iterator_t iterator;
    kern_return_t kr = IOServiceGetMatchingServices(kIOMainPortDefault,
                                                    IOServiceMatching("IOUSBHostDevice"),
                                                    &iterator);
    
    if (kr == KERN_SUCCESS) {
        io_service_t service;
        while ((service = IOIteratorNext(iterator))) {
            NSMutableDictionary *usbDevice = [NSMutableDictionary dictionary];
            
            CFTypeRef vendorID = IORegistryEntryCreateCFProperty(service,
                                                                CFSTR("idVendor"),
                                                                kCFAllocatorDefault, 0);
            if (vendorID) {
                usbDevice[@"vendorID"] = [NSString stringWithFormat:@"0x%04X",
                                        [(__bridge NSNumber *)vendorID intValue]];
                CFRelease(vendorID);
            }
            
            CFTypeRef productID = IORegistryEntryCreateCFProperty(service,
                                                                 CFSTR("idProduct"),
                                                                 kCFAllocatorDefault, 0);
            if (productID) {
                usbDevice[@"productID"] = [NSString stringWithFormat:@"0x%04X",
                                         [(__bridge NSNumber *)productID intValue]];
                CFRelease(productID);
            }
            
            CFTypeRef productName = IORegistryEntryCreateCFProperty(service,
                                                                   CFSTR("USB Product Name"),
                                                                   kCFAllocatorDefault, 0);
            if (productName) {
                usbDevice[@"name"] = (__bridge NSString *)productName;
                CFRelease(productName);
            }
            
            CFTypeRef manufacturer = IORegistryEntryCreateCFProperty(service,
                                                                    CFSTR("USB Vendor Name"),
                                                                    kCFAllocatorDefault, 0);
            if (manufacturer) {
                usbDevice[@"manufacturer"] = (__bridge NSString *)manufacturer;
                CFRelease(manufacturer);
            }
            
            if (usbDevice.count > 0) {
                [usb addObject:usbDevice];
            }
            
            IOObjectRelease(service);
        }
        IOObjectRelease(iterator);
    }
    
    return usb;
}

#pragma mark - System Info

- (NSDictionary *)detectSystemInfo {
    NSMutableDictionary *sysInfo = [NSMutableDictionary dictionary];
    
    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault,
                                                       IOServiceMatching("IOPlatformExpertDevice"));
    
    if (service) {
        CFTypeRef model = IORegistryEntryCreateCFProperty(service,
                                                         CFSTR("model"),
                                                         kCFAllocatorDefault, 0);
        if (model) {
            NSData *modelData = (__bridge NSData *)model;
            sysInfo[@"model"] = [[NSString alloc] initWithData:modelData encoding:NSUTF8StringEncoding];
            CFRelease(model);
        }
        
        CFTypeRef serial = IORegistryEntryCreateCFProperty(service,
                                                          CFSTR("IOPlatformSerialNumber"),
                                                          kCFAllocatorDefault, 0);
        if (serial) {
            sysInfo[@"serial"] = (__bridge NSString *)serial;
            CFRelease(serial);
        }
        
        CFTypeRef uuid = IORegistryEntryCreateCFProperty(service,
                                                        CFSTR("IOPlatformUUID"),
                                                        kCFAllocatorDefault, 0);
        if (uuid) {
            sysInfo[@"uuid"] = (__bridge NSString *)uuid;
            CFRelease(uuid);
        }
        
        IOObjectRelease(service);
    }
    
    return sysInfo;
}

#pragma mark - OpenCore Report Generation

- (NSDictionary *)generateOpenCoreReport:(HardwareInfo *)hardware {
    NSMutableDictionary *report = [NSMutableDictionary dictionary];
    
    // Hardware section
    NSMutableDictionary *hardwareSection = [NSMutableDictionary dictionary];
    
    // CPU
    hardwareSection[@"CPU"] = @{
        @"Brand": hardware.cpuBrand ?: @"Unknown",
        @"Model": hardware.cpuModel ?: @"Unknown",
        @"Cores": @(hardware.cpuCores),
        @"Threads": @(hardware.cpuThreads),
        @"Architecture": hardware.cpuArchitecture ?: @"Unknown",
        @"Frequency": @(hardware.cpuFrequency)
    };
    
    // Motherboard
    hardwareSection[@"Motherboard"] = @{
        @"Manufacturer": hardware.motherboardManufacturer ?: @"Unknown",
        @"Model": hardware.motherboardModel ?: @"Unknown",
        @"BIOSVersion": hardware.biosVersion ?: @"Unknown",
        @"BIOSDate": hardware.biosDate ?: @"Unknown"
    };
    
    // Memory
    NSMutableArray *memArray = [NSMutableArray array];
    for (NSDictionary *module in hardware.memoryModules) {
        [memArray addObject:@{
            @"Size": module[@"size"] ?: @0,
            @"Type": module[@"type"] ?: @"Unknown",
            @"Manufacturer": module[@"manufacturer"] ?: @"Unknown"
        }];
    }
    hardwareSection[@"Memory"] = @{
        @"Total": @(hardware.totalMemory),
        @"Modules": memArray
    };
    
    // GPU
    NSMutableArray *gpuArray = [NSMutableArray array];
    for (NSDictionary *gpu in hardware.gpuDevices) {
        [gpuArray addObject:@{
            @"Model": gpu[@"model"] ?: @"Unknown",
            @"VendorID": gpu[@"vendorID"] ?: @"Unknown",
            @"DeviceID": gpu[@"deviceID"] ?: @"Unknown",
            @"VRAM": gpu[@"vram"] ?: @0
        }];
    }
    hardwareSection[@"GPU"] = gpuArray;
    
    // Storage
    NSMutableArray *storageArray = [NSMutableArray array];
    for (NSDictionary *drive in hardware.storageDevices) {
        [storageArray addObject:@{
            @"Model": drive[@"model"] ?: @"Unknown",
            @"Manufacturer": drive[@"manufacturer"] ?: @"Unknown",
            @"Size": drive[@"size"] ?: @0,
            @"Type": drive[@"type"] ?: @"Unknown"
        }];
    }
    hardwareSection[@"Storage"] = storageArray;
    
    // Network
    NSMutableArray *networkArray = [NSMutableArray array];
    for (NSDictionary *net in hardware.networkDevices) {
        [networkArray addObject:@{
            @"Interface": net[@"interface"] ?: @"Unknown",
            @"MACAddress": net[@"macAddress"] ?: @"Unknown",
            @"VendorID": net[@"vendorID"] ?: @"Unknown",
            @"DeviceID": net[@"deviceID"] ?: @"Unknown"
        }];
    }
    hardwareSection[@"Network"] = networkArray;
    
    // Audio
    NSMutableArray *audioArray = [NSMutableArray array];
    for (NSDictionary *audio in hardware.audioDevices) {
        [audioArray addObject:audio];
    }
    hardwareSection[@"Audio"] = audioArray;
    
    report[@"Hardware"] = hardwareSection;
    
    // System Info
    report[@"SystemInfo"] = @{
        @"Model": hardware.systemModel ?: @"Unknown",
        @"SerialNumber": hardware.systemSerial ?: @"Unknown",
        @"UUID": hardware.systemUUID ?: @"Unknown"
    };
    
    // Metadata
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZ"];
    NSString *dateString = [dateFormatter stringFromDate:[NSDate date]];
    
    report[@"Metadata"] = @{
        @"Generator": @"DarwinSniffer",
        @"Version": @"1.0",
        @"GeneratedDate": dateString,
        @"Platform": @"macOS",
        @"CompatibleWith": @"OpenCore Simplify"
    };
    
    return (NSDictionary *)SanitizeJSONValue(report);
}

- (NSString *)generateJSONReport:(HardwareInfo *)hardware {
    NSDictionary *report = [self generateOpenCoreReport:hardware];
    
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:report
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&error];
    
    if (error) {
        NSLog(@"Error generating JSON: %@", error);
        return nil;
    }
    
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

- (BOOL)saveReportToFile:(NSDictionary *)report path:(NSString *)path {
    NSError *error;
    NSDictionary *safeReport = (NSDictionary *)SanitizeJSONValue(report);
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:safeReport
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&error];
    
    if (error) {
        NSLog(@"Error generating JSON: %@", error);
        return NO;
    }
    
    return [jsonData writeToFile:path options:NSDataWritingAtomic error:&error];
}

@end
