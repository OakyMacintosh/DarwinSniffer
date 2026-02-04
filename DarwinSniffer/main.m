//
//  main.m
//  DarwinSniffer
//
//  Created by Oaky on 03/02/26.
//

#import <Foundation/Foundation.h>
#import "DarwinSniffer.h"

void printUsage(void) {
    printf("DarwinSniffer - Hardware Detection Tool for macOS\n");
    printf("Generates OpenCore Simplify compatible hardware reports\n\n");
    printf("Usage: DarwinSniffer [options]\n\n");
    printf("Options:\n");
    printf("  -o, --output <path>    Output file path (default: hardware_report.json)\n");
    printf("  -v, --verbose          Show detailed output\n");
    printf("  -h, --help             Show this help message\n");
    printf("  --cpu                  Show only CPU information\n");
    printf("  --gpu                  Show only GPU information\n");
    printf("  --memory               Show only memory information\n");
    printf("  --storage              Show only storage information\n");
    printf("  --network              Show only network information\n");
    printf("  --audio                Show only audio information\n");
    printf("  --all                  Show all hardware (default)\n\n");
    printf("Examples:\n");
    printf("  DarwinSniffer                           # Generate full report\n");
    printf("  DarwinSniffer -o ~/Desktop/hw.json      # Save to Desktop\n");
    printf("  DarwinSniffer --cpu --verbose           # Show CPU info only\n\n");
}

void printCPUInfo(NSDictionary *cpuInfo) {
    printf("\n=== CPU Information ===\n");
    printf("Brand:        %s\n", [cpuInfo[@"brand"] UTF8String] ?: "Unknown");
    printf("Model:        %s\n", [cpuInfo[@"model"] UTF8String] ?: "Unknown");
    printf("Architecture: %s\n", [cpuInfo[@"architecture"] UTF8String] ?: "Unknown");
    printf("Cores:        %ld\n", (long)[cpuInfo[@"cores"] integerValue]);
    printf("Threads:      %ld\n", (long)[cpuInfo[@"threads"] integerValue]);
    printf("Frequency:    %.2f MHz\n", [cpuInfo[@"frequency"] doubleValue]);
}

void printGPUInfo(NSArray *gpus) {
    printf("\n=== GPU Information ===\n");
    for (NSInteger i = 0; i < gpus.count; i++) {
        NSDictionary *gpu = gpus[i];
        printf("\nGPU %ld:\n", (long)i);
        printf("  Model:     %s\n", [gpu[@"model"] UTF8String] ?: "Unknown");
        printf("  Vendor ID: %s\n", [gpu[@"vendorID"] UTF8String] ?: "Unknown");
        printf("  Device ID: %s\n", [gpu[@"deviceID"] UTF8String] ?: "Unknown");
        if (gpu[@"vram"]) {
            unsigned long long vram = [gpu[@"vram"] unsignedLongLongValue];
            printf("  VRAM:      %llu MB\n", vram / (1024 * 1024));
        }
    }
}

void printMemoryInfo(NSArray *modules, unsigned long long total) {
    printf("\n=== Memory Information ===\n");
    printf("Total Memory: %.2f GB\n", total / (1024.0 * 1024.0 * 1024.0));
    printf("\nModules:\n");
    for (NSInteger i = 0; i < modules.count; i++) {
        NSDictionary *module = modules[i];
        printf("\nModule %ld:\n", (long)i);
        unsigned long long size = [module[@"size"] unsignedLongLongValue];
        printf("  Size:         %.2f GB\n", size / (1024.0 * 1024.0 * 1024.0));
        printf("  Type:         %s\n", [module[@"type"] UTF8String] ?: "Unknown");
        printf("  Manufacturer: %s\n", [module[@"manufacturer"] UTF8String] ?: "Unknown");
    }
}

void printStorageInfo(NSArray *storage) {
    printf("\n=== Storage Information ===\n");
    for (NSInteger i = 0; i < storage.count; i++) {
        NSDictionary *drive = storage[i];
        printf("\nDrive %ld:\n", (long)i);
        printf("  Model:        %s\n", [drive[@"model"] UTF8String] ?: "Unknown");
        printf("  Manufacturer: %s\n", [drive[@"manufacturer"] UTF8String] ?: "Unknown");
        printf("  Type:         %s\n", [drive[@"type"] UTF8String] ?: "Unknown");
        if (drive[@"size"]) {
            unsigned long long size = [drive[@"size"] unsignedLongLongValue];
            printf("  Size:         %.2f GB\n", size / (1024.0 * 1024.0 * 1024.0));
        }
        if (drive[@"bsdName"]) {
            printf("  BSD Name:     %s\n", [drive[@"bsdName"] UTF8String]);
        }
    }
}

void printNetworkInfo(NSArray *network) {
    printf("\n=== Network Information ===\n");
    for (NSInteger i = 0; i < network.count; i++) {
        NSDictionary *net = network[i];
        printf("\nInterface %ld:\n", (long)i);
        printf("  Name:       %s\n", [net[@"interface"] UTF8String] ?: "Unknown");
        printf("  MAC:        %s\n", [net[@"macAddress"] UTF8String] ?: "Unknown");
        printf("  Vendor ID:  %s\n", [net[@"vendorID"] UTF8String] ?: "Unknown");
        printf("  Device ID:  %s\n", [net[@"deviceID"] UTF8String] ?: "Unknown");
    }
}

void printAudioInfo(NSArray *audio) {
    printf("\n=== Audio Information ===\n");
    for (NSInteger i = 0; i < audio.count; i++) {
        NSDictionary *device = audio[i];
        printf("\nAudio Device %ld:\n", (long)i);
        printf("  Type: %s\n", [device[@"type"] UTF8String] ?: "Unknown");
        if (device[@"codecID"]) {
            printf("  Codec ID: 0x%08X\n", [device[@"codecID"] unsignedIntValue]);
        }
        if (device[@"vendorID"]) {
            printf("  Vendor ID: %s\n", [device[@"vendorID"] UTF8String]);
        }
    }
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSString *outputPath = @"hardware_report.json";
        BOOL verbose = NO;
        BOOL showCPU = NO;
        BOOL showGPU = NO;
        BOOL showMemory = NO;
        BOOL showStorage = NO;
        BOOL showNetwork = NO;
        BOOL showAudio = NO;
        BOOL showAll = YES;
        
        // Parse command-line arguments
        for (int i = 1; i < argc; i++) {
            NSString *arg = [NSString stringWithUTF8String:argv[i]];
            
            if ([arg isEqualToString:@"-h"] || [arg isEqualToString:@"--help"]) {
                printUsage();
                return 0;
            }
            else if ([arg isEqualToString:@"-v"] || [arg isEqualToString:@"--verbose"]) {
                verbose = YES;
            }
            else if ([arg isEqualToString:@"-o"] || [arg isEqualToString:@"--output"]) {
                if (i + 1 < argc) {
                    outputPath = [NSString stringWithUTF8String:argv[i + 1]];
                    i++;
                } else {
                    fprintf(stderr, "Error: --output requires a file path\n");
                    return 1;
                }
            }
            else if ([arg isEqualToString:@"--cpu"]) {
                showCPU = YES;
                showAll = NO;
            }
            else if ([arg isEqualToString:@"--gpu"]) {
                showGPU = YES;
                showAll = NO;
            }
            else if ([arg isEqualToString:@"--memory"]) {
                showMemory = YES;
                showAll = NO;
            }
            else if ([arg isEqualToString:@"--storage"]) {
                showStorage = YES;
                showAll = NO;
            }
            else if ([arg isEqualToString:@"--network"]) {
                showNetwork = YES;
                showAll = NO;
            }
            else if ([arg isEqualToString:@"--audio"]) {
                showAudio = YES;
                showAll = NO;
            }
            else if ([arg isEqualToString:@"--all"]) {
                showAll = YES;
            }
        }
        
        if (showAll) {
            showCPU = showGPU = showMemory = showStorage = showNetwork = showAudio = YES;
        }
        
        printf("DarwinSniffer - macOS Hardware Detection Tool\n");
        printf("==============================================\n");
        
        DarwinSniffer *sniffer = [DarwinSniffer sharedInstance];
        
        if (verbose) {
            printf("\nDetecting hardware...\n");
        }
        
        HardwareInfo *hardware = [sniffer detectHardware];
        
        if (!hardware) {
            fprintf(stderr, "Error: Failed to detect hardware\n");
            return 1;
        }
        
        // Print requested information
        if (showCPU) {
            NSDictionary *cpuInfo = [sniffer detectCPU];
            printCPUInfo(cpuInfo);
        }
        
        if (showGPU && hardware.gpuDevices.count > 0) {
            printGPUInfo(hardware.gpuDevices);
        }
        
        if (showMemory) {
            printMemoryInfo(hardware.memoryModules, hardware.totalMemory);
        }
        
        if (showStorage && hardware.storageDevices.count > 0) {
            printStorageInfo(hardware.storageDevices);
        }
        
        if (showNetwork && hardware.networkDevices.count > 0) {
            printNetworkInfo(hardware.networkDevices);
        }
        
        if (showAudio && hardware.audioDevices.count > 0) {
            printAudioInfo(hardware.audioDevices);
        }
        
        // Generate and save report
        printf("\n\nGenerating OpenCore compatible report...\n");
        
        NSDictionary *report = [sniffer generateOpenCoreReport:hardware];
        
        // Expand tilde in output path
        outputPath = [outputPath stringByExpandingTildeInPath];
        
        BOOL success = [sniffer saveReportToFile:report path:outputPath];
        
        if (success) {
            printf("✓ Report saved to: %s\n", [outputPath UTF8String]);
            
            if (verbose) {
                printf("\nReport Summary:\n");
                printf("  CPU: %s\n", [hardware.cpuBrand UTF8String] ?: "Unknown");
                printf("  Memory: %.2f GB\n", hardware.totalMemory / (1024.0 * 1024.0 * 1024.0));
                printf("  GPUs: %ld\n", (long)hardware.gpuDevices.count);
                printf("  Storage Devices: %ld\n", (long)hardware.storageDevices.count);
                printf("  Network Interfaces: %ld\n", (long)hardware.networkDevices.count);
                printf("  Audio Devices: %ld\n", (long)hardware.audioDevices.count);
            }
        } else {
            fprintf(stderr, "✗ Error: Failed to save report to %s\n", [outputPath UTF8String]);
            return 1;
        }
        
        printf("\nReport is compatible with OpenCore Simplify\n");
    }
    return 0;
}
