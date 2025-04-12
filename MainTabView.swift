import SwiftUI

struct MainTabView: View {
    @State private var selection = 0
    @EnvironmentObject var audioManager: OptimizedAudioPlayerManager
    @EnvironmentObject var albumManager: AlbumCollectionManager // Ajout pour SettingsView
    @State private var showPlayer = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selection) {
                LibraryView()
                    .tabItem {
                        Label("Bibliothèque", systemImage: "square.stack.fill")
                    }
                    .tag(0)
                
                PlaylistsView()
                    .tabItem {
                        Label("Playlists", systemImage: "music.note.list")
                    }
                    .tag(1)
                
                SettingsView()
                    .tabItem {
                        Label("Réglages", systemImage: "gear")
                    }
                    .tag(2)
            }
            .accentColor(.accentColor)
            
            // Mini-player persistant en bas si une musique est en cours
            if audioManager.currentTrack != nil {
                MiniPlayerView()
                    .background(.thinMaterial)
                    .cornerRadius(10, corners: [.topLeft, .topRight])
                    .shadow(radius: 2)
                    .onTapGesture {
                        showPlayer = true
                    }
                    .padding(.bottom, 49)
            }
        }
        .sheet(isPresented: $showPlayer) {
            PlayerView()
                .environmentObject(audioManager)
                .environmentObject(albumManager) // Propager à PlayerView si nécessaire
        }
    }
}

// Extension pour permettre d'arrondir seulement certains coins
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// Vue mini-player affichée en bas
struct MiniPlayerView: View {
    @EnvironmentObject var audioManager: OptimizedAudioPlayerManager
    
    var body: some View {
        HStack(spacing: 15) {
            // Artwork
            if let artwork = audioManager.currentTrack?.artwork {
                Image(uiImage: artwork)
                    .resizable()
                    .frame(width: 50, height: 50)
                    .cornerRadius(6)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .cornerRadius(6)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.caption)
                            .foregroundColor(.gray)
                    )
            }
            
            // Info piste
            VStack(alignment: .leading, spacing: 2) {
                Text(audioManager.currentTrack?.title ?? "")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                Text(audioManager.currentTrack?.artist ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Contrôles
            HStack(spacing: 20) {
                Button(action: {
                    if audioManager.isPlaying {
                        audioManager.pause()
                    } else {
                        audioManager.resume()
                    }
                }) {
                    Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .foregroundColor(.accentColor)
                }
                
                Button(action: {
                    if let currentTrack = audioManager.currentTrack {
                        audioManager.play(track: currentTrack)
                    }
                }) {
                    Image(systemName: "forward.fill")
                        .font(.title3)
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.trailing, 10)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .frame(height: 70)
    }
}

#Preview {
    MainTabView()
        .environmentObject(OptimizedAudioPlayerManager.shared)
        .environmentObject(AlbumCollectionManager()) // Ajout pour le preview
}
