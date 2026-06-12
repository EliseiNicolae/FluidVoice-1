import Foundation

actor PrivateAIIntegrationService {
    static let shared = PrivateAIIntegrationService()

    static var selectedModelDefaultsKey: String {
        PrivateAIProviderFeature.shared.selectedModelDefaultsKey
    }

    static var localModelPathDefaultsKey: String {
        PrivateAIProviderFeature.shared.localModelPathDefaultsKey
    }

    struct RuntimeConfiguration: Sendable, Equatable {
        let selectedProviderID: String
        let providerKey: String
        let baseURL: String
        let model: String
        let apiKey: String
        let localModelPath: String?
        let usesStablePromptPrefixKVCache: Bool
    }

    struct AppContext: Sendable, Equatable {
        let appName: String
        let bundleID: String
        let windowTitle: String
        let appVersion: String?
    }

    struct EnhancementResult: Sendable, Equatable {
        let outputText: String
        let backendKind: String?
        let latencyMilliseconds: Int?
    }

    struct LoadedModelState: Sendable, Equatable {
        let modelID: String
        let state: PrivateAIRuntimeState
        let message: String?
    }

    private init() {}

    private nonisolated static var provider: any PrivateAIIntegrationProviding {
        PrivateAIProviderFeature.shared.isAvailable
            ? PrivateAIProviderRegistry.integration
            : UnavailableAIIntegrationShim.shared
    }

    nonisolated static var configuredModelID: String {
        provider.configuredModelID
    }

    nonisolated static var selectedModel: PrivateAIRegisteredModel {
        provider.selectedModel
    }

    nonisolated static var configuredLocalModelPath: String? {
        provider.configuredLocalModelPath
    }

    nonisolated static var modelDirectoryURL: URL {
        provider.modelDirectoryURL
    }

    nonisolated static func expectedLocalModelURL(for model: PrivateAIRegisteredModel) -> URL {
        self.provider.expectedLocalModelURL(for: model)
    }

    nonisolated static func localModelPath(for model: PrivateAIRegisteredModel) -> String? {
        self.provider.localModelPath(for: model)
    }

    nonisolated static func isModelInstalled(_ model: PrivateAIRegisteredModel) -> Bool {
        self.provider.isModelInstalled(model)
    }

    nonisolated static func prepareModel(
        _ model: PrivateAIRegisteredModel,
        progressHandler: PrivateAIModelDownloadProgressHandler? = nil
    ) async throws -> URL {
        try await self.provider.prepareModel(model, progressHandler: progressHandler)
    }

    nonisolated static var isLocalRuntimeConfigured: Bool {
        provider.isLocalRuntimeConfigured
    }

    nonisolated static func shouldHandleDictation(model: String) -> Bool {
        self.provider.shouldHandleDictation(model: model)
    }

    func status(for runtime: RuntimeConfiguration) async -> PrivateAIStatus {
        await Self.provider.status(for: runtime)
    }

    func loadedModelState() async -> LoadedModelState? {
        await Self.provider.loadedModelState()
    }

    func loadModel(_ model: PrivateAIRegisteredModel) async throws -> PrivateAIStatus {
        try await Self.provider.loadModel(model)
    }

    func unloadCachedRuntime(reason: String = "manual") async {
        await Self.provider.unloadCachedRuntime(reason: reason)
    }

    func enhanceDictation(
        _ inputText: String,
        runtime: RuntimeConfiguration,
        context: AppContext
    ) async throws -> EnhancementResult {
        try await Self.provider.enhanceDictation(inputText, runtime: runtime, context: context)
    }
}

private struct UnavailableAIIntegrationShim: PrivateAIIntegrationProviding {
    static let shared = UnavailableAIIntegrationShim()

    var configuredModelID: String { PrivateAIModelRegistry.defaultModelID }
    var selectedModel: PrivateAIRegisteredModel { PrivateAIModelRegistry.defaultModel }
    var configuredLocalModelPath: String? { nil }
    var modelDirectoryURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("FluidVoice", isDirectory: true)
            .appendingPathComponent(PrivateAIProviderFeature.shared.modelDirectoryName, isDirectory: true)
            .appendingPathComponent("Models", isDirectory: true)
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("FluidVoice", isDirectory: true)
            .appendingPathComponent(PrivateAIProviderFeature.shared.modelDirectoryName, isDirectory: true)
            .appendingPathComponent("Models", isDirectory: true)
    }

    var isLocalRuntimeConfigured: Bool { false }

    func expectedLocalModelURL(for model: PrivateAIRegisteredModel) -> URL {
        PrivateAIModelRegistry.localModelURL(for: model, directoryURL: self.modelDirectoryURL)
    }

    func localModelPath(for _: PrivateAIRegisteredModel) -> String? { nil }
    func isModelInstalled(_: PrivateAIRegisteredModel) -> Bool { false }

    func prepareModel(
        _: PrivateAIRegisteredModel,
        progressHandler _: PrivateAIModelDownloadProgressHandler?
    ) async throws -> URL {
        throw PrivateAIUnavailableError()
    }

    func shouldHandleDictation(model _: String) -> Bool { false }

    func status(for _: PrivateAIIntegrationService.RuntimeConfiguration) async -> PrivateAIStatus {
        PrivateAIStatus(
            state: .unavailable,
            message: PrivateAIUnavailableError().errorDescription
        )
    }

    func loadedModelState() async -> PrivateAIIntegrationService.LoadedModelState? { nil }

    func loadModel(_: PrivateAIRegisteredModel) async throws -> PrivateAIStatus {
        throw PrivateAIUnavailableError()
    }

    func unloadCachedRuntime(reason _: String) async {}

    func enhanceDictation(
        _ inputText: String,
        runtime _: PrivateAIIntegrationService.RuntimeConfiguration,
        context _: PrivateAIIntegrationService.AppContext
    ) async throws -> PrivateAIIntegrationService.EnhancementResult {
        PrivateAIIntegrationService.EnhancementResult(
            outputText: inputText,
            backendKind: nil,
            latencyMilliseconds: nil
        )
    }
}
