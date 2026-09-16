import Foundation
import LectureRecorderCore

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var downloadProgress: [ModelVariant: Double] = [:]
    @Published var downloadError: String?

    private let service = TranscriptionService()

    func download(_ variant: ModelVariant) {
        Task {
            downloadProgress[variant] = 0
            do {
                try await service.downloadModel(variant) { fraction in
                    Task { @MainActor in self.downloadProgress[variant] = fraction }
                }
                downloadProgress[variant] = 1
            } catch {
                downloadError = error.localizedDescription
                downloadProgress[variant] = nil
            }
        }
    }

    func delete(_ variant: ModelVariant) {
        Task {
            try? await service.removeModel(variant)
        }
    }
}
