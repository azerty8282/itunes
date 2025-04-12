import SwiftUI

struct AlbumDetailView: View {
    let album: Album
    @EnvironmentObject var audioManager: OptimizedAudioPlayerManager
    @State private var showingPlayButton = false
    @Environment(\.colorScheme) var colorScheme
    @State private var displayArtwork: UIImage? = nil
    
    // Propriété calculée pour trier les pistes par trackNumber, pistes sans trackNumber en bas
    private var sortedTracks: [Track] {
        album.tracks.sorted { track1, track2 in
            // Si les deux pistes ont un trackNumber valide (> 0), on compare les numéros
            if track1.trackNumber > 0 && track2.trackNumber > 0 {
                return track1.trackNumber < track2.trackNumber
            }
            // Si track1 n'a pas de trackNumber valide, il va à la fin
            if track1.trackNumber <= 0 {
                return false
            }
            // Si track2 n'a pas de trackNumber valide, track1 passe avant
            if track2.trackNumber <= 0 {
                return true
            }
            // Par défaut, on conserve l'ordre
            return true
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // En-tête avec image de couverture et informations générales
                VStack(alignment: .center) {
                    // Pochette de l'album (plus grande et centrée)
                    ZStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 240, height: 240)
                            .cornerRadius(8)
                        
                        if let artwork = displayArtwork {
                            Image(uiImage: artwork)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 240, height: 240)
                                .cornerRadius(8)
                        } else {
                            Image(systemName: "music.note")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                        }
                    }
                    .shadow(radius: 4)
                    .padding(.top, 20)
                    
                    // Titre et artiste centrés
                    Text(album.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .padding(.top, 0)
                    
                    Text(album.artist)
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .padding(.top, 0)
                    
                    // Boutons d'action principaux
                    HStack(spacing: 40) {
                        // Bouton de lecture
                        Button(action: {
                            if let firstTrack = sortedTracks.first {
                                audioManager.play(track: firstTrack, from: album)
                            }
                        }) {
                            VStack {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.red)
                                Text("Lecture")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        
                        // Bouton aléatoire
                        Button(action: {
                            if let randomTrack = sortedTracks.randomElement() {
                                audioManager.play(track: randomTrack, from: album)
                            }
                        }) {
                            VStack {
                                Image(systemName: "shuffle")
                                    .font(.system(size: 30))
                                    .foregroundColor(.red)
                                Text("Aléatoire")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .padding(.vertical, 12)
                }
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.systemBackground))
                
                // Séparateur
                Divider()
                    .padding(.horizontal)
                
                // Section Disque 1
                VStack(alignment: .leading) {
                    Text("Disque 1")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                    
                    // Liste des pistes triées par trackNumber
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(sortedTracks) { track in
                            TrackRow(track: track, album: album)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    audioManager.play(track: track, from: album)
                                }
                            Divider()
                                .padding(.leading, 40)
                        }
                    }
                    
                    // Informations sur le nombre de morceaux et la durée totale
                    VStack(alignment: .center, spacing: 4) {
                        HStack(spacing: 20) {
                            Text("\(album.tracks.count) morceaux")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            let totalDuration = album.tracks.reduce(0) { $0 + $1.duration }
                            Text(formatDuration(totalDuration))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            if album.playCount > 0 {
                                Text("Écouté \(album.playCount) fois")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
                    .padding(.bottom, 20)
                }
            }
        }
        .background(Color(UIColor.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadSynchronousArtwork()
        }
    }
    
    // Méthode sécurisée pour charger l'artwork de manière synchrone
    private func loadSynchronousArtwork() {
        if let directArtwork = album.artwork {
            self.displayArtwork = directArtwork
            return
        }
        
        if let cachedArtwork = ArtworkCacheManager.shared.getImage(for: album.id) {
            self.displayArtwork = cachedArtwork
            return
        }
    }
    
    // Formater la durée en heures:minutes:secondes
    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0s"
    }
    
    // Toggle le statut d'épinglage
    private func togglePinStatus() {
        NotificationCenter.default.post(
            name: Notification.Name("AlbumPinStatusToggled"),
            object: nil,
            userInfo: ["albumID": album.id]
        )
    }
}

// Composant pour une ligne de piste
struct TrackRow: View {
    let track: Track
    let album: Album
    let displayIndex: Int? // Paramètre optionnel pour l'index d'affichage
    @EnvironmentObject var audioManager: OptimizedAudioPlayerManager
    @Environment(\.colorScheme) var colorScheme
    
    // Initialisation avec un index d'affichage optionnel
    init(track: Track, album: Album, displayIndex: Int? = nil) {
        self.track = track
        self.album = album
        self.displayIndex = displayIndex
    }
    
    // Vérifier si cette piste est en cours de lecture
    private var isCurrentlyPlaying: Bool {
        guard let currentTrack = audioManager.currentTrack else { return false }
        return currentTrack.id == track.id && audioManager.isPlaying
    }
    
    // Vérifier si cette piste est chargée mais en pause
    private var isCurrentButPaused: Bool {
        guard let currentTrack = audioManager.currentTrack else { return false }
        return currentTrack.id == track.id && !audioManager.isPlaying
    }
    
    // Calculer le numéro de piste à afficher (optionnel)
    private var displayTrackNumber: Int? {
        if let index = displayIndex {
            return index
        } else {
            return track.trackNumber > 0 ? track.trackNumber : nil
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Numéro de piste ou icône de lecture
            if isCurrentlyPlaying {
                Image(systemName: "pause.circle.fill")
                    .foregroundColor(.red)
                    .frame(width: 24)
                    .onTapGesture {
                        audioManager.pause()
                    }
            } else if isCurrentButPaused {
                Image(systemName: "play.circle.fill")
                    .foregroundColor(.red)
                    .frame(width: 24)
                    .onTapGesture {
                        audioManager.resume()
                    }
            } else if let number = displayTrackNumber {
                Text("\(number)")
                    .foregroundColor(.secondary)
                    .frame(width: 24)
            } else {
                Text("")
                    .frame(width: 24)
            }
            
            // Titre de la piste
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .fontWeight(isCurrentlyPlaying || isCurrentButPaused ? .bold : .regular)
                    .foregroundColor(isCurrentlyPlaying || isCurrentButPaused ? .red : .primary)
                
                if track.artist != album.artist {
                    Text(track.artist)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Durée de la piste
            Text(formatDuration(track.duration))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 45, alignment: .trailing)
        }
        .padding(.vertical, 12)
        .padding(.horizontal)
        .contextMenu {
            Button(action: {
                deleteTrack()
            }) {
                Label("Supprimer", systemImage: "trash")
            }
            
            Button(action: {
                addToFavorites()
            }) {
                Label("Ajouter aux favoris", systemImage: "heart")
            }
        }
    }
    
    // Formater la durée en minutes:secondes
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // Fonction pour supprimer la piste
    private func deleteTrack() {
        NotificationCenter.default.post(
            name: Notification.Name("TrackDeleteRequested"),
            object: nil,
            userInfo: ["trackID": track.id, "albumID": album.id]
        )
    }
    
    // Fonction pour ajouter aux favoris
    private func addToFavorites() {
        NotificationCenter.default.post(
            name: Notification.Name("TrackAddedToFavorites"),
            object: nil,
            userInfo: ["track": track]
        )
    }
}
