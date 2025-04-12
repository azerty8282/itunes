import SwiftUI
import AVFoundation

struct PlayerView: View {
    @EnvironmentObject var audioManager: OptimizedAudioPlayerManager
    @Environment(\.colorScheme) var systemColorScheme
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.dismiss) private var dismiss // Pour les versions iOS 15+
    
    @GestureState private var dragState = DragState.inactive
    @State private var viewOffset: CGFloat = 0
    
    // Drag state enum pour suivre l'état du swipe
    enum DragState {
        case inactive
        case dragging(translation: CGSize)
        
        var translation: CGSize {
            switch self {
            case .inactive:
                return .zero
            case .dragging(let translation):
                return translation
            }
        }
        
        var isDragging: Bool {
            switch self {
            case .inactive:
                return false
            case .dragging:
                return true
            }
        }
    }
    
    @GestureState private var dragOffset: CGFloat = 0
    @State private var seekPosition: Double = 0
    @State private var isDragging = false
    
    @AppStorage("playerTrackFadeInDuration") private var fadeInDuration: Double = 0
    @AppStorage("playerTrackFadeOutDuration") private var trackFadeOutDuration: Double = 2.5
    @AppStorage("pauseFadeOutDuration") private var pauseFadeOutDuration: Double = 2.5
    @AppStorage("settingsOverlapDuration") private var overlapDuration: Double = 15.0
    @State private var isSmoothTransitionEnabled: Bool = false
    
    @State private var showSFXSheet: Bool = false
    @AppStorage("sfxValue") private var sfxValue: Double = 0.0
    @AppStorage("colorMode") private var colorMode: String = "Aucun"
    
    @State private var customColorScheme: ExtractedColorScheme = ExtractedColorScheme(fond: .gray, accent1: .white, accent2: .white)
    @State private var isFadingOut: Bool = false
    
    private var duration: Double {
        return audioManager.currentTrack?.duration ?? 0
    }
    
    private var currentTime: Double {
        return duration * audioManager.currentProgress
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Fond uni avec la couleur dominante (activé en mode "Algorithme")
                if colorMode == "Algorithme" {
                    Color(customColorScheme.fond)
                        .ignoresSafeArea()
                        .scaleEffect(2.0)
                } else {
                    Color(systemColorScheme == .light ? .white : .black)
                        .ignoresSafeArea()
                }
                
                // Jaquette floue par-dessus le fond uni (activé uniquement en mode "Algorithme")
                if colorMode == "Algorithme", let artwork = audioManager.currentTrack?.artwork {
                    Image(uiImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .scaleEffect(1.2)
                        .blur(radius: 100)
                        .clipped()
                        .ignoresSafeArea()
                }
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 15) {
                        HStack {
                            Spacer()
                            // Indicateur visuel pour le swipe down
                            Rectangle()
                                .fill(Color.gray.opacity(0.5))
                                .frame(width: 40, height: 5)
                                .cornerRadius(2.5)
                            Spacer()
                        }
                        .padding(.top, 10)
                        
                        playerContentView
                            .frame(maxWidth: geometry.size.width)
                    }
                    .padding(.horizontal, 15)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .offset(y: max(0, self.viewOffset))
                .animation(.interactiveSpring(), value: viewOffset)
                .gesture(
                    DragGesture()
                        .updating($dragState) { value, state, _ in
                            state = .dragging(translation: value.translation)
                        }
                        .onChanged { value in
                            // Ne permet que le glissement vers le bas
                            if value.translation.height > 0 {
                                self.viewOffset = value.translation.height
                            }
                        }
                        .onEnded { value in
                            // Ferme la vue si le glissement est suffisant
                            if value.translation.height > geometry.size.height * 0.2 {
                                self.dismiss()
                            } else {
                                self.viewOffset = 0
                            }
                        }
                )
            }
        }
        .ignoresSafeArea(.all, edges: .bottom)
        .onAppear {
            seekPosition = currentTime
            updateSmoothTransitionState()
            sfxValue = Double(audioManager.pitchValue)
            if colorMode == "Algorithme", let album = audioManager.currentAlbum {
                let artwork = audioManager.currentTrack?.artwork ?? album.artwork
                updateColors(for: album.id, artwork: artwork)
            }
        }
        .onChange(of: audioManager.currentAlbum?.id) { newAlbumID in
            if colorMode == "Algorithme", let albumID = newAlbumID, let album = audioManager.currentAlbum {
                let artwork = audioManager.currentTrack?.artwork ?? album.artwork
                updateColors(for: albumID, artwork: artwork)
            }
        }
        .onChange(of: colorMode) { newValue in
            if newValue == "Algorithme", let album = audioManager.currentAlbum {
                let artwork = audioManager.currentTrack?.artwork ?? album.artwork
                updateColors(for: album.id, artwork: artwork)
            }
        }
        .sheet(isPresented: $showSFXSheet) {
            sfxSheetView
        }
    }
    
    private func updateColors(for albumID: UUID, artwork: UIImage?) {
        if let cachedPalette = ColorPaletteCache.shared.getPalette(for: albumID) {
            customColorScheme = ExtractedColorScheme(
                fond: UIColor(cachedPalette["fond"] ?? .gray),
                accent1: UIColor(cachedPalette["accent1"] ?? .white),
                accent2: UIColor(cachedPalette["accent2"] ?? .white)
            )
        } else {
            Task.detached(priority: .background) {
                let scheme = artwork?.extrairePaletteCouleurs() ?? ExtractedColorScheme(fond: .gray, accent1: .white, accent2: .white)
                let palette = [
                    "fond": Color(scheme.fond),
                    "accent1": Color(scheme.accent1),
                    "accent2": Color(scheme.accent2)
                ]
                ColorPaletteCache.shared.setPalette(palette, for: albumID)
                await MainActor.run {
                    customColorScheme = scheme
                }
            }
        }
    }
    
    private var sfxSheetView: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Titre et description
                VStack(spacing: 8) {
                    Text("Ajuster la tonalité")
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundColor(colorMode == "Algorithme" ? Color(customColorScheme.accent2) : .primary)
                    
                    Text("Modifiez la hauteur tonale sans affecter le tempo de la piste.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(colorMode == "Algorithme" ? Color(customColorScheme.accent2).opacity(0.7) : .secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Slider pour la tonalité
                VStack(spacing: 12) {
                    Slider(
                        value: $sfxValue,
                        in: -12...12,
                        step: 0.1,
                        minimumValueLabel: Text("-12").font(.caption2).foregroundColor(.secondary),
                        maximumValueLabel: Text("+12").font(.caption2).foregroundColor(.secondary)
                    ) {
                        Text("Tonalité")
                    }
                    .accentColor(colorMode == "Algorithme" ? Color(customColorScheme.accent1) : .accentColor)
                    .padding(.horizontal)
                    .onChange(of: sfxValue) { newValue in
                        applyAudioEffect(value: newValue)
                    }
                    
                    // Affichage de la valeur et description
                    VStack(spacing: 4) {
                        Text("Valeur : \(String(format: "%.1f", sfxValue)) demi-tons")
                            .font(.system(.headline, design: .rounded))
                            .foregroundColor(colorMode == "Algorithme" ? Color(customColorScheme.accent2) : .primary)
                        
                        Text(getPitchDescription(sfxValue))
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(colorMode == "Algorithme" ? Color(customColorScheme.accent2).opacity(0.7) : .secondary)
                    }
                }
                
                // Boutons d'incréments et reset
                HStack(spacing: 20) {
                    Button(action: {
                        sfxValue = max(-12, sfxValue - 1)
                        applyAudioEffect(value: sfxValue)
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(colorMode == "Algorithme" ? Color(customColorScheme.accent1) : .accentColor)
                            .background(
                                Circle()
                                    .fill(Color(UIColor.systemBackground).opacity(0.8))
                                    .frame(width: 44, height: 44)
                            )
                    }
                    
                    Button(action: {
                        sfxValue = 0
                        applyAudioEffect(value: sfxValue)
                    }) {
                        Text("Réinitialiser")
                            .font(.system(.callout, design: .rounded, weight: .medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(UIColor.systemBackground).opacity(0.8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(colorMode == "Algorithme" ? Color(customColorScheme.accent1) : .accentColor, lineWidth: 1)
                                    )
                            )
                            .foregroundColor(colorMode == "Algorithme" ? Color(customColorScheme.accent1) : .accentColor)
                    }
                    
                    Button(action: {
                        sfxValue = min(12, sfxValue + 1)
                        applyAudioEffect(value: sfxValue)
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(colorMode == "Algorithme" ? Color(customColorScheme.accent1) : .accentColor)
                            .background(
                                Circle()
                                    .fill(Color(UIColor.systemBackground).opacity(0.8))
                                    .frame(width: 44, height: 44)
                            )
                    }
                }
                .padding(.vertical, 10)
                
                // Préréglages
                Text("Préréglages")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundColor(colorMode == "Algorithme" ? Color(customColorScheme.accent2) : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach([(-5.0, "-5"), (-3.0, "-3"), (3.0, "+3"), (5.0, "+5")], id: \.0) { preset in
                        Button(action: {
                            sfxValue = preset.0
                            applyAudioEffect(value: preset.0)
                        }) {
                            Text(preset.1)
                                .font(.system(.callout, design: .rounded, weight: .medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(abs(sfxValue - preset.0) < 0.1 ? (colorMode == "Algorithme" ? Color(customColorScheme.accent1).opacity(0.2) : Color.accentColor.opacity(0.2)) : Color(UIColor.systemBackground).opacity(0.8))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(abs(sfxValue - preset.0) < 0.1 ? (colorMode == "Algorithme" ? Color(customColorScheme.accent1) : .accentColor) : .clear, lineWidth: 1)
                                        )
                                )
                                .foregroundColor(abs(sfxValue - preset.0) < 0.1 ? (colorMode == "Algorithme" ? Color(customColorScheme.accent1) : .accentColor) : (colorMode == "Algorithme" ? Color(customColorScheme.accent2) : .primary))
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.vertical, 20)
            .background(
                VisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
                    .ignoresSafeArea()
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: {
                        showSFXSheet = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private struct PresetButton: View {
        let label: String
        let value: Double
        let currentValue: Double
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                Text(label)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(abs(currentValue - value) < 0.1 ? Color.red : Color.gray.opacity(0.2))
                    )
                    .foregroundColor(abs(currentValue - value) < 0.1 ? .white : .primary)
            }
        }
    }
    
    private func getPitchDescription(_ value: Double) -> String {
        switch value {
        case -12: return "Une octave plus bas"
        case -7: return "Une quinte parfaite plus bas"
        case -5: return "Une quarte juste plus bas"
        case -3: return "Une tierce mineure plus bas"
        case -2: return "Un ton plus bas"
        case -1: return "Un demi-ton plus bas"
        case 0: return "Tonalité d'origine"
        case 1: return "Un demi-ton plus haut"
        case 2: return "Un ton plus haut"
        case 3: return "Une tierce mineure plus haut"
        case 5: return "Une quarte juste plus haut"
        case 7: return "Une quinte parfaite plus haut"
        case 12: return "Une octave plus haut"
        default: return "Tonalité modifiée"
        }
    }
    
    private func applyAudioEffect(value: Double) {
        audioManager.applyPitchEffect(Float(value))
    }
    
    private func updateSmoothTransitionState() {
        isSmoothTransitionEnabled = fadeInDuration > 0 && trackFadeOutDuration > 0
    }
    
    private var playerContentView: some View {
        VStack(spacing: 15) {
            if let artwork = audioManager.currentTrack?.artwork {
                Image(uiImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: min(UIScreen.main.bounds.width * 0.85, 350), height: min(UIScreen.main.bounds.width * 0.85, 350))
                    .cornerRadius(12)
                    .shadow(radius: 10)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: min(UIScreen.main.bounds.width * 0.85, 350), height: min(UIScreen.main.bounds.width * 0.85, 350))
                    .cornerRadius(20)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 90))
                            .foregroundColor(.gray)
                    )
            }
            
            VStack(spacing: 4) {
                Text(audioManager.currentTrack?.title ?? "")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .foregroundColor(colorMode == "Algorithme" ? Color(customColorScheme.accent2) : .primary)
                
                Text(audioManager.currentTrack?.artist ?? "")
                    .font(.body)
                    .foregroundColor(colorMode == "Algorithme" ? Color(customColorScheme.accent2) : .secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal)
            .padding(.bottom, 5)
            
            VStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Fade in (nouvelle piste)")
                            .font(.caption)
                            .foregroundColor(colorMode == "Algorithme" ? Color(customColorScheme.accent2) : .secondary)
                        Spacer()
                        Text(String(format: "%.1f", fadeInDuration) + " sec")
                            .font(.caption)
                            .foregroundColor(colorMode == "Algorithme" ? Color(customColorScheme.accent2) : .secondary)
                    }
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 4)
                                .cornerRadius(2)
                            
                            Rectangle()
                                .fill(colorMode == "Algorithme" ? Color(customColorScheme.accent1) : (systemColorScheme == .light ? Color.gray : Color.white))
                                .frame(width: geometry.size.width * CGFloat(fadeInDuration / 12), height: 4)
                                .cornerRadius(2)
                                .animation(.default, value: fadeInDuration)
                        }
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let percentage = max(0, min(1, value.location.x / geometry.size.width))
                                    fadeInDuration = percentage * 12
                                    updateSmoothTransitionState()
                                }
                        )
                    }
                    .frame(height: 10)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Fade out (piste suivante)")
                            .font(.caption)
                            .foregroundColor(colorMode == "Algorithme" ? Color(customColorScheme.accent2) : .secondary)
                        Spacer()
                        Text(String(format: "%.1f", trackFadeOutDuration) + " sec")
                            .font(.caption)
                            .foregroundColor(colorMode == "Algorithme" ? Color(customColorScheme.accent2) : .secondary)
                    }
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 4)
                                .cornerRadius(2)
                            
                            Rectangle()
                                .fill(colorMode == "Algorithme" ? Color(customColorScheme.accent1) : (systemColorScheme == .light ? Color.gray : Color.white))
                                .frame(width: geometry.size.width * CGFloat(trackFadeOutDuration / 12), height: 4)
                                .cornerRadius(2)
                                .animation(.default, value: trackFadeOutDuration)
                        }
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let percentage = max(0, min(1, value.location.x / geometry.size.width))
                                    trackFadeOutDuration = percentage * 12
                                    updateSmoothTransitionState()
                                }
                        )
                    }
                    .frame(height: 10)
                }
            }
            .padding(.horizontal)
            
            VStack(spacing: 5) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 4)
                            .cornerRadius(2)
                        
                        Rectangle()
                            .fill(colorMode == "Algorithme" ? Color(customColorScheme.accent1) : (systemColorScheme == .light ? Color.gray : Color.white))
                            .frame(
                                width: calculateProgressWidth(
                                    geometry: geometry,
                                    isDragging: isDragging,
                                    dragOffset: dragOffset,
                                    seekPosition: seekPosition,
                                    currentTime: currentTime,
                                    duration: duration
                                ),
                                height: 4
                            )
                            .cornerRadius(2)
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .updating($dragOffset) { value, state, _ in
                                if isDragging {
                                    let newOffset = value.translation.width
                                    state = newOffset
                                }
                            }
                            .onChanged { value in
                                isDragging = true
                                let percentage = max(0, min(1, (value.location.x / geometry.size.width)))
                                seekPosition = percentage * duration
                            }
                            .onEnded { value in
                                let percentage = max(0, min(1, (value.location.x / geometry.size.width)))
                                audioManager.seekToPercent(percentage)
                                isDragging = false
                            }
                    )
                }
                .frame(height: 20)
                .contentShape(Rectangle())
                
                HStack {
                    Text(formatTime(isDragging ? seekPosition : currentTime))
                        .foregroundColor(colorMode == "Algorithme" ? Color(customColorScheme.accent2) : .secondary)
                    Spacer()
                    Text("-" + formatTime(duration - (isDragging ? seekPosition : currentTime)))
                        .foregroundColor(colorMode == "Algorithme" ? Color(customColorScheme.accent2) : .secondary)
                }
                .font(.caption)
            }
            .padding(.horizontal)
            
            HStack(spacing: 40) {
                Button(action: {
                    audioManager.playPreviousWithTransition(fadeInDuration: fadeInDuration, fadeOutDuration: trackFadeOutDuration)
                }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 28))
                        .foregroundColor(colorMode == "Algorithme" ? Color(customColorScheme.accent1) : .primary)
                }
                
                Button(action: {
                    if audioManager.isPlaying && pauseFadeOutDuration > 0 {
                        isFadingOut = true
                        audioManager.togglePlayPause()
                        DispatchQueue.main.asyncAfter(deadline: .now() + pauseFadeOutDuration) {
                            isFadingOut = false
                        }
                    } else {
                        isFadingOut = false
                        audioManager.togglePlayPause()
                    }
                }) {
                    if isFadingOut {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(colorMode == "Algorithme" ? Color(customColorScheme.accent1) : .primary)
                            .scaleEffect(2.0)
                    } else {
                        Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 56))
                            .foregroundColor(colorMode == "Algorithme" ? Color(customColorScheme.accent1) : .primary)
                    }
                }
                
                Button(action: {
                    audioManager.playNextWithTransition(fadeInDuration: fadeInDuration, fadeOutDuration: trackFadeOutDuration)
                }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 28))
                        .foregroundColor(colorMode == "Algorithme" ? Color(customColorScheme.accent1) : .primary)
                }
            }
            .padding(.vertical, 5)
            
            HStack(spacing: 30) {
                Button(action: {
                    showSFXSheet = true
                }) {
                    Image(systemName: "dial.min")
                        .font(.title3)
                        .foregroundColor(colorMode == "Algorithme" ? (sfxValue != 0 ? Color.red : Color(customColorScheme.accent1)) : (sfxValue != 0 ? .red : .primary))
                        .opacity(colorMode == "Algorithme" && sfxValue == 0 ? 1.0 : 1.0)
                }
                
                Button(action: {
                    audioManager.changerModeRepetition()
                    if audioManager.modeRepetition == .toutLire {
                        overlapDuration = 15.0
                    }
                }) {
                    Image(systemName: repeatModeIcon)
                        .font(.title3)
                        .foregroundColor(colorMode == "Algorithme" ? Color(customColorScheme.accent1) : (audioManager.modeRepetition != .aucun ? .blue : .primary))
                        .opacity(colorMode == "Algorithme" && audioManager.modeRepetition == .aucun ? 0.3 : 1.0)
                }
                
                Button(action: {
                    audioManager.toggleShuffle()
                }) {
                    Image(systemName: "shuffle")
                        .font(.title3)
                        .foregroundColor(colorMode == "Algorithme" ? Color(customColorScheme.accent1) : (audioManager.isShuffleEnabled ? .blue : .primary))
                        .opacity(colorMode == "Algorithme" && !audioManager.isShuffleEnabled ? 0.3 : 1.0)
                }
                
                Button(action: {
                    isSmoothTransitionEnabled.toggle()
                    if isSmoothTransitionEnabled {
                        fadeInDuration = 12.0
                        trackFadeOutDuration = 12.0
                        overlapDuration = 15.0
                    } else {
                        fadeInDuration = 0.0
                        trackFadeOutDuration = 2.5
                        overlapDuration = 0.0
                    }
                }) {
                    Image(systemName: isSmoothTransitionEnabled ? "waveform" : "waveform.slash")
                        .font(.title3)
                        .foregroundColor(colorMode == "Algorithme" ? Color(customColorScheme.accent1) : (isSmoothTransitionEnabled ? .blue : .primary))
                        .opacity(colorMode == "Algorithme" && !isSmoothTransitionEnabled ? 0.3 : 1.0)
                }
            }
            
            Spacer()
        }
    }
    
    private func calculateProgressWidth(
        geometry: GeometryProxy,
        isDragging: Bool,
        dragOffset: CGFloat,
        seekPosition: Double,
        currentTime: Double,
        duration: Double
    ) -> CGFloat {
        if isDragging {
            let base = geometry.size.width * CGFloat(seekPosition / max(1, duration))
            return max(0, min(geometry.size.width, base + dragOffset))
        } else {
            return geometry.size.width * CGFloat(currentTime / max(1, duration))
        }
    }
    
    private var repeatModeIcon: String {
        switch audioManager.modeRepetition {
        case .aucun: return "repeat"
        case .toutLire: return "repeat"
        case .uneTitre: return "repeat.1"
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// VisualEffectView pour le fond flou du sheet
struct VisualEffectView: UIViewRepresentable {
    let effect: UIVisualEffect
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: effect)
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = effect
    }
}
