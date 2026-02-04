//
//  DarwinSniffer.h
//  DarwinSniffer
//
//  Created by Oaky on 03/02/26.
//

#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/network/IOEthernetInterface.h>
#import <IOKit/network/IONetworkInterface.h>
#import <IOKit/network/IOEthernetController.h>
#import <IOKit/usb/IOUSBLib.h>
#import <IOKit/graphics/IOGraphicsLib.h>
#import <IOKit/pwr_mgt/IOPMLib.h>
#import <IOKit/storage/IOStorageDeviceCharacteristics.h>

@interface HardwareInfo : NSObject

@property (nonatomic, strong) NSString *cpuBrand;
@property (nonatomic, strong) NSString *cpuModel;
@property (nonatomic, assign) NSInteger cpuCores;
@property (nonatomic, assign) NSInteger cpuThreads;
@property (nonatomic, strong) NSString *cpuArchitecture;
@property (nonatomic, assign) double cpuFrequency;

@property (nonatomic, strong) NSString *motherboardManufacturer;
@property (nonatomic, strong) NSString *motherboardModel;
@property (nonatomic, strong) NSString *biosVersion;
@property (nonatomic, strong) NSString *biosDate;

@property (nonatomic, assign) unsigned long long totalMemory;
@property (nonatomic, strong) NSArray *memoryModules;

@property (nonatomic, strong) NSArray *gpuDevices;
@property (nonatomic, strong) NSArray *storageDevices;
@property (nonatomic, strong) NSArray *networkDevices;
@property (nonatomic, strong) NSArray *audioDevices;
@property (nonatomic, strong) NSArray *usbControllers;

@property (nonatomic, strong) NSString *systemModel;
@property (nonatomic, strong) NSString *systemSerial;
@property (nonatomic, strong) NSString *systemUUID;

@end

@interface DarwinSniffer : NSObject

+ (instancetype)sharedInstance;

- (HardwareInfo *)detectHardware;
- (NSDictionary *)generateOpenCoreReport:(HardwareInfo *)hardware;
- (BOOL)saveReportToFile:(NSDictionary *)report path:(NSString *)path;
- (NSString *)generateJSONReport:(HardwareInfo *)hardware;

// Individual component detection
- (NSDictionary *)detectCPU;
- (NSDictionary *)detectMotherboard;
- (NSArray *)detectMemory;
- (NSArray *)detectGPU;
- (NSArray *)detectStorage;
- (NSArray *)detectNetwork;
- (NSArray *)detectAudio;
- (NSArray *)detectUSB;
- (NSDictionary *)detectSystemInfo;

@end
