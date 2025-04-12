import SwiftUI

struct ContentView: View {
    @EnvironmentObject var albumManager: AlbumCollectionManager // Récupérer pour propagation
    
    var body: some View {
        MainTabView()
            .environmentObject(albumManager) // Propager AlbumCollectionManager
            .environmentObject(OptimizedAudioPlayerManager.shared)
    }
}

#Preview {
    ContentView()
        .environmentObject(AlbumCollectionManager())
        .environmentObject(OptimizedAudioPlayerManager.shared)
}
