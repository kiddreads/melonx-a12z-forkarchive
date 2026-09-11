//
//  MeloNXApp.swift
//  MeloNX
//
//  Created by Stossy11 on 09/11/2025.
//

import SwiftUI

struct EnvironmentVariable: Codable, Hashable {
    let string: String
    var value: String
    
    func set() {
        setenv(string, value, 1)
    }
    
    static func set(_ env: EnvironmentVariable) {
        setenv(env.string, env.value, 1)
    }
}

struct MeloNXApp: View {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("hasbeenfinished") var inSetup: Bool = true
    @AppStorage("skippedSetup") var skippedSetup: Bool = false
    @AppStorage("firstBoot") var firstBoot: Bool = false
    @State var viewShown = false
    @State var showedSetup = false

    
    /// A12Z-only knobs. These are the whole point of this clone: one variable at a
    /// time, flipped from the UI, so a tester can produce a clean A/B on real hardware
    /// instead of us guessing from source.
    ///
    /// MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS is the first suspect. Tier 2 argument
    /// buffers need Apple GPU family 6 (A13+); A12Z is family 5, so it is Tier 1, where
    /// the limits collapse to roughly 96/128 textures and 16 samplers. MeloNX upstream
    /// sets UseMetalArgumentBuffers = true in MVKInitialization.cs; Stossy11 commented
    /// that line out on 2025-11-02 in a commit titled only "A lot", with no stated
    /// reason - so this exact setting has already been toggled once by someone chasing
    /// something. The env var overrides whatever the C# does.
    @AppStorage("a12z_argument_buffers") static var argumentBuffersEnabled: Bool = false
    @AppStorage("a12z_metal_private_api") static var metalPrivateAPIEnabled: Bool = true

    var environment: [EnvironmentVariable] {
        var vars: [EnvironmentVariable] = [
            EnvironmentVariable(string: "MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS",
                                value: Self.argumentBuffersEnabled ? "1" : "0"),
        ]
        if Self.metalPrivateAPIEnabled {
            vars.append(contentsOf: baseEnvironment)
        } else {
            vars.append(contentsOf: baseEnvironment.filter {
                !$0.string.contains("METAL_PRIVATE_API")
            })
        }
        return vars
    }

    let baseEnvironment: [EnvironmentVariable] = [
        EnvironmentVariable(string: "MVK_USE_METAL_PRIVATE_API", value: "1"),
        EnvironmentVariable(string: "MVK_CONFIG_USE_METAL_PRIVATE_API", value: "1"),
        EnvironmentVariable(string: "MVK_DEBUG", value: "0"),
        // EnvironmentVariable(string: "MVK_CONFIG_PREFILL_METAL_COMMAND_BUFFERS", value: "0"),
        EnvironmentVariable(string: "MVK_CONFIG_MAX_ACTIVE_METAL_COMMAND_BUFFERS_PER_QUEUE", value: "128"),
        // EnvironmentVariable(string: "MVK_CONFIG_SHADER_COMPRESSION_ALGORITHM", value: "4"),
        EnvironmentVariable(string: "DOTNET_DefaultStackSize", value: "200000") // probably doesn't work on NativeAOT
    ]
    
    let fileManager = FileManager.default
    
    init() {
        // Log the device profile before anything else touches Metal or SDL. If this
        // build crashes during startup, this is the last thing written, and it is
        // exactly the information a bug report needs.
        NSLog("[a12z] device profile:\n%@", A12Z.report)
        SDL_SetMainReady()
        SDL_iPhoneSetEventPump(SDL_TRUE)
        SDL_Init(SDL_INIT_EVENTS | SDL_INIT_AUDIO)
        setupEnvironment()
    }
    
    var body: some View {
        Group {
            if !A12Z.isA12Z {
                // Refuse, rather than run degraded. A result from this build is only
                // evidence about the A12Z if it can only have come from an A12Z.
                WrongDeviceView()
            } else if !inSetup {
                ContentView(viewShown: $viewShown)
                    .onAppear() {
                        
                        if skippedSetup {
                            return
                        }
                        
                        if !Ryujinx.shared.checkIfKeysImported() {
                            inSetup = true
                        }
                        let firmware = Ryujinx.shared.fetchFirmwareVersion()
                        
                        if (firmware == "" ? "0" : firmware) == "0" {
                            inSetup = true
                        }
                        
                        // NSExtension Test
                        
                        
                    }
            } else {
                SetupView(isInSetup: $inSetup)
                    .onAppear() {
                        let mp3 = MusicSelectorView.getMP3s().first(where: { $0.builtIn })
                        MusicSelectorView.playMusic(mp3)
                        skippedSetup = false
                    }
                    .onDisappear {
                        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { _ in
                            let music = NativeSettingsManager.shared.backgroundMusic("").value
                            MusicSelectorView.stopMusic()
                            if music.isEmpty {
                                if let mp3 = MusicSelectorView.getMP3s().last(where: { $0.builtIn }) {
                                    MusicSelectorView.setMusicItemPath(mp3)
                                    MusicSelectorView.playMusic()
                                }
                            } else {
                                MusicSelectorView.playMusic()
                            }
                        }
                    }
            }
        }
    }
    
    func setupEnvironment() {
        environment.forEach { env in
            env.set()
        }
        
        EnvironmentVariable(string: "HAS_TXM", value: ProcessInfo.processInfo.hasTXM && !ProcessInfo.processInfo.isiOSAppOnMac ? "1" : "0").set()

        RyujinxBridge.initialize()
        
        let cool: Bool
        if #available(iOS 19, *) {
            if ProcessInfo.processInfo.hasTXM {
                NativeSettingsManager.shared.setting(forKey: "DUAL_MAPPED_JIT", default: true).value = true
            }
            
            cool = NativeSettingsManager.shared.setting(forKey: "DUAL_MAPPED_JIT", default: true).value
        } else {
            cool = NativeSettingsManager.shared.setting(forKey: "DUAL_MAPPED_JIT", default: false).value
        }
        
        JIT26BreakpointHandler()
        
        if cool {
            EnvironmentVariable(string: "DUAL_MAPPED_JIT", value: "1").set()
            LaunchGameHandler.succeededJIT = RyujinxBridge.initialize_dualmapped()
        } else {
            EnvironmentVariable(string: "DUAL_MAPPED_JIT", value: "0").set()
        }
    }
}


