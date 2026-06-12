import Foundation

enum PrivateAIProviderPromptFormat {
    static var promptSelectionID: String {
        PrivateAIProviderFeature.shared.promptSelectionID
    }

    nonisolated static func matches(model: String) -> Bool {
        PrivateAIProviderFeature.shared.matches(model: model)
    }

    static func isAvailable(settings: SettingsStore = .shared) -> Bool {
        self.matches(model: self.selectedDictationModel(settings: settings))
    }

    private static func selectedDictationModel(settings: SettingsStore) -> String {
        let providerID = settings.selectedProviderID
        let selectedModelByProvider = settings.selectedModelByProvider

        if let saved = settings.savedProviders.first(where: { $0.id == providerID }) {
            let key = "custom:\(saved.id)"
            return selectedModelByProvider[key] ?? saved.models.first ?? ""
        }

        if ModelRepository.shared.isBuiltIn(providerID) {
            return selectedModelByProvider[providerID] ?? ModelRepository.shared.defaultModels(for: providerID).first ?? ""
        }

        return selectedModelByProvider[providerID] ?? ""
    }
}
