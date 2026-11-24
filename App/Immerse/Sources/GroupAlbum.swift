import CryptoKit
import ImmerseServer
#if !APPCLIP
import Photos
#endif
import SwiftUI

/// The revealed album (v2 PRD V2-FR-43 to V2-FR-45): every picture in capture order across all guests, with numbered gaps
/// where one was withdrawn or removed, each opening full screen with its details. The reveal ritual shows the first time
/// a member opens it (V2-FR-38). Any member saves any picture or the whole album to Photos with no Account (V2-FR-44).
///
/// In the mini-app, saving is one picture at a time through the system's share sheet, and the whole album is saved in
/// the full app or from the web album (open check OC-6): Apple gives an App Clip no use of PhotoKit and no access to
/// Photos, so the mini-app never asks for either.
struct GroupAlbumSection: View {
    @Environment(\.groupFilms) private var groupFilms
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let eventID: String
    @State private var album: Album?
    @State private var failure: String?
    @State private var ritual: Double?
    @State private var opened: AlbumPicture?
    @State private var saving: Int?
    /// The note before the first save of the whole album. A single picture's is shown over the picture itself
    /// (`AlbumPictureView`), since nothing can be presented from under its full-screen view.
    @State private var notingBeforeSavingAll = false

    private enum SaveRequest: Identifiable {
        case one(AlbumPicture)
        case all
        var id: String {
            switch self {
            case .one(let picture): picture.pictureId
            case .all: "all"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            OrbitSectionLabel("The album").padding(.leading, 4).padding(.top, 8)
            if let ritual {
                ZStack {
                    OrbitRing(progress: ritual, lineWidth: 6)
                    Text("Your Film is ready").orbitFont(.headline)
                }
                .frame(width: 200, height: 200).frame(maxWidth: .infinity)
                .accessibilityIdentifier("group-reveal-ritual")
            } else if let album {
                grid(album)
                saveAll(album)
            } else if let failure {
                OrbitNote(.error, failure, identifier: "group-album-problem")
                Button("Try Again") { Task { await load() } }.buttonStyle(OrbitPillStyle(kind: .outline, minHeight: 44))
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
        .task { await load() }
        .fullScreenCover(item: $opened) { picture in
            AlbumPictureView(eventID: eventID, picture: picture, isHost: album?.isHost ?? false, camera: album?.camera ?? .disposable,
                             save: { perform(.one(picture)) }) {
                Task { await load() }
            }
        }
        .sheet(isPresented: $notingBeforeSavingAll) {
            SavedCopiesNote { perform(.all) }
        }
    }

    private func load() async {
        guard let groupFilms else { return }
        do {
            let loaded = try await groupFilms.album(eventID)
            if groupFilms.place(eventID)?.revealSeen == false {
                groupFilms.markRevealSeen(eventID)
                if !reduceMotion {
                    ritual = 0
                    withAnimation(.easeInOut(duration: 1.6)) { ritual = 1 }
                    try? await Task.sleep(for: .seconds(1.8))
                }
                ritual = nil
            }
            album = loaded
            failure = nil
        } catch {
            failure = GroupFilmsCopy.words(for: error)
        }
    }

    private func grid(_ album: Album) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 6)], spacing: 6) {
            ForEach(album.entries) { entry in
                switch entry {
                case .picture(let picture):
                    Button { opened = picture } label: {
                        AsyncImage(url: picture.viewUrl) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Orbit.surface
                        }
                        .frame(minWidth: 0, maxWidth: .infinity).aspectRatio(1, contentMode: .fill).clipped()
                        .overlay(alignment: .bottomLeading) { number(picture.number) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Picture \(picture.number), by \(picture.shooterName)")
                    .accessibilityIdentifier("group-album-picture")
                case .gap(let number):
                    RoundedRectangle(cornerRadius: 3).strokeBorder(Orbit.hairline)
                        .aspectRatio(1, contentMode: .fit)
                        .overlay { self.number(number) }
                        .accessibilityLabel("Picture \(number), removed")
                        .accessibilityIdentifier("group-album-gap")
                }
            }
        }
    }

    private func number(_ value: Int) -> some View {
        Text(String(format: "%02d", value)).orbitFont(.footnote).foregroundStyle(.white).padding(4)
    }

    @ViewBuilder private func saveAll(_ album: Album) -> some View {
        #if APPCLIP
        if album.entries.contains(where: { if case .picture = $0 { true } else { false } }) {
            let onTheWeb = groupFilms?.place(eventID)?.summary.isOnTheWeb == true
            OrbitNote(.info, onTheWeb ? GroupFilmsCopy.miniAppSaveAllOnTheWeb : GroupFilmsCopy.miniAppSaveAll,
                      identifier: "group-save-in-app")
        }
        #else
        let pictures = album.entries.compactMap { if case .picture(let picture) = $0 { picture } else { nil } }
        let saved = groupFilms?.place(eventID)?.savedPictures ?? []
        let left = pictures.filter { !saved.contains($0.pictureId) }.count
        if let saving {
            ProgressView(value: Double(saving), total: Double(max(pictures.count, 1))) {
                Text("Saving \(saving) of \(pictures.count)").orbitFont(.footnote)
            }
        } else if !pictures.isEmpty {
            Button(left == pictures.count ? "Save the Whole Album" : left == 0 ? "All Saved to Photos" : "Save the Remaining \(left)") {
                if SavedCopiesNote.shown { perform(.all) } else { notingBeforeSavingAll = true }
            }
            .buttonStyle(OrbitPillStyle(kind: .outline, minHeight: 48, fullWidth: true))
            .disabled(left == 0)
            .accessibilityIdentifier("group-save-all")
        }
        #endif
    }

    private func perform(_ request: SaveRequest) {
        Task {
            switch request {
            case .one(let picture):
                #if APPCLIP
                await share(picture)
                #else
                await save([picture])
                #endif
            case .all:
                #if !APPCLIP
                await saveWholeAlbum()
                #endif
            }
        }
    }

    /// The picture with read addresses that have not run out: its own, or fresh ones from the server, which also says
    /// whether the person may still see it.
    private func current(_ picture: AlbumPicture) async -> AlbumPicture? {
        if picture.addressesExpireAt > .now.addingTimeInterval(10) { return picture }
        guard let fresh = try? await groupFilms?.album(eventID) else { return nil }
        album = fresh
        for case .picture(let candidate) in fresh.entries where candidate.pictureId == picture.pictureId { return candidate }
        return nil
    }

    /// The full picture as uploaded, checked against the checksum the album gave.
    private func download(_ picture: AlbumPicture) async -> Data? {
        guard let groupFilms else { return nil }
        guard let picture = await current(picture),
              let (data, response) = try? await URLSession.shared.data(from: picture.url) else {
            groupFilms.notice = "Saving stopped. Check the connection, then try again."
            return nil
        }
        #if DEBUG
        // The Debug stand-in's album is files on this iPhone, with no checksum (DebugGroupFilms).
        if picture.url.isFileURL { return data }
        #endif
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              Data(SHA256.hash(data: data)).base64EncodedString() == picture.sha256 else {
            groupFilms.notice = "A picture did not download whole. Try again."
            return nil
        }
        return data
    }

    #if APPCLIP
    /// The mini-app hands one picture, as uploaded, to the system's share sheet, which saves or sends it (open check OC-6).
    @discardableResult
    private func share(_ picture: AlbumPicture) async -> Bool {
        guard let data = await download(picture) else { return false }
        let name = String(format: "Immerse %03d.%@", picture.number, picture.contentType == "image/heic" ? "heic" : "jpg")
        let folder = FileManager.default.temporaryDirectory.appending(path: "Shared", directoryHint: .isDirectory)
        let file = folder.appending(path: name)
        do {
            try? FileManager.default.removeItem(at: folder)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try data.write(to: file, options: .atomic)
        } catch {
            groupFilms?.notice = "Immerse could not get the picture ready. Free space and try again."
            return false
        }
        ShareSheet.present([file])
        return true
    }
    #else
    /// Saves every picture visible now that is not saved yet, resuming where an interrupted save stopped, and fetching
    /// fresh addresses as they run out.
    private func saveWholeAlbum() async {
        guard let groupFilms else { return }
        var album = self.album
        var done = 0
        saving = 0
        defer { saving = nil }
        while true {
            if album == nil || album!.entries.contains(where: { if case .picture(let p) = $0 { p.addressesExpireAt < .now.addingTimeInterval(10) } else { false } }) {
                album = try? await groupFilms.album(eventID)
            }
            guard let current = album else { break }
            let saved = groupFilms.place(eventID)?.savedPictures ?? []
            let next = current.entries.compactMap { if case .picture(let p) = $0, !saved.contains(p.pictureId) { p } else { nil } }
            guard let picture = next.first else { break }
            guard await save([picture]) else { break }
            done += 1
            saving = done
        }
        groupFilms.notice = done > 0 ? "\(done) \(done == 1 ? "picture" : "pictures") saved to Photos." : groupFilms.notice
    }

    @discardableResult
    private func save(_ pictures: [AlbumPicture]) async -> Bool {
        guard let groupFilms else { return false }
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            groupFilms.notice = "Saving needs permission to add to Photos. Allow it for Immerse in iPhone Settings."
            return false
        }
        for picture in pictures {
            do {
                guard let data = await download(picture) else { return false }
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
                }
                groupFilms.markSaved(eventID, pictureID: picture.pictureId)
            } catch {
                groupFilms.notice = "Saving stopped. Check the connection, then save the rest."
                return false
            }
        }
        return true
    }
    #endif
}

#if APPCLIP
/// The system's share sheet over whatever is on the screen, the picture's full view included.
@MainActor
enum ShareSheet {
    static func present(_ items: [Any]) {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first { $0.activationState == .foregroundActive }
        guard var top = scene?.keyWindow?.rootViewController else { return }
        while let presented = top.presentedViewController {
            if presented.isBeingDismissed {
                // The note that asked is still leaving the screen, and nothing can be presented until it has: the sheet
                // follows it.
                if let leaving = presented.transitionCoordinator {
                    leaving.animate(alongsideTransition: nil) { _ in present(items) }
                } else {
                    DispatchQueue.main.async { present(items) }
                }
                return
            }
            top = presented
        }
        let sheet = UIActivityViewController(activityItems: items, applicationActivities: nil)
        sheet.popoverPresentationController?.sourceView = top.view
        top.present(sheet, animated: true)
    }
}
#endif

/// Said once, before the first save (V2-FR-44): a saved picture is an independent copy that removing it later cannot
/// recall. It is presented by whatever is on top, the album or one picture's full view.
struct SavedCopiesNote: View {
    private static let key = "ImmerseSavedCopiesNoteShown"
    static var shown: Bool { UserDefaults.standard.bool(forKey: key) }
    let save: () -> Void

    #if APPCLIP
    private static let title = "Save a Picture"
    #else
    private static let title = "Save to Photos"
    #endif

    var body: some View {
        GroupConfirmSheet(title: Self.title, message: GroupFilmsCopy.savedCopiesNote, confirm: "Save") {
            UserDefaults.standard.set(true, forKey: Self.key)
            save()
        }
    }
}

/// One picture full screen (V2-FR-45): its details (Guest Name, capture time and Camera), Save, and Remove for its shooter
/// or the Host, or Report for anyone else (V2-FR-51 to V2-FR-54). Nothing edits, captions or reorders it.
struct AlbumPictureView: View {
    @Environment(\.groupFilms) private var groupFilms
    @Environment(\.dismiss) private var dismiss
    let eventID: String
    let picture: AlbumPicture
    let isHost: Bool
    let camera: EventCamera
    let save: () -> Void
    let changed: () -> Void
    @State private var confirmRemove = false
    @State private var reporting = false
    @State private var notingBeforeSaving = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                AsyncImage(url: picture.viewUrl) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    ProgressView()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel("Picture \(picture.number)")
                VStack(spacing: 4) {
                    Text(picture.shooterName).orbitFont(.headline).accessibilityIdentifier("group-picture-name")
                    Text("\(picture.capturedAt.formatted(date: .abbreviated, time: .shortened)) · \(GroupFilmsCopy.camera(camera))")
                        .orbitFont(.footnote).foregroundStyle(Orbit.label)
                }
                HStack(spacing: 24) {
                    Button("Save", systemImage: "square.and.arrow.down") {
                        if SavedCopiesNote.shown { save() } else { notingBeforeSaving = true }
                    }
                        .buttonStyle(OrbitLabelledActionStyle(emphasized: true))
                        .accessibilityIdentifier("group-picture-save")
                    if picture.mine || isHost {
                        Button("Remove", systemImage: "trash") { confirmRemove = true }
                            .buttonStyle(OrbitLabelledActionStyle())
                            .accessibilityIdentifier("group-picture-remove")
                    } else {
                        Button("Report", systemImage: "exclamationmark.bubble") { reporting = true }
                            .buttonStyle(OrbitLabelledActionStyle())
                            .accessibilityIdentifier("group-picture-report")
                    }
                }
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            }
            .foregroundStyle(.white)
            .padding()
            .background(Color.black.ignoresSafeArea())
            .environment(\.colorScheme, .dark)
            .navigationTitle("Picture \(picture.number)").toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", systemImage: "checkmark") { dismiss() }.buttonStyle(OrbitCircleButtonStyle(selected: true))
                }
                .sharedBackgroundVisibility(.hidden)
            }
        }
        .sheet(isPresented: $confirmRemove) {
            GroupConfirmSheet(title: "Remove picture \(picture.number)?", message: picture.mine ? GroupFilmsCopy.removeMine : GroupFilmsCopy.removeAsHost,
                              confirm: "Remove") {
                Task {
                    let removed = picture.mine
                        ? await groupFilms?.removeMyPicture(eventID, exposureNumber: picture.exposureNumber)
                        : await groupFilms?.removePictureAsHost(eventID, pictureID: picture.pictureId)
                    if removed == true { changed(); dismiss() }
                }
            }
        }
        .sheet(isPresented: $reporting) { ReportSheet(eventID: eventID, pictureID: picture.pictureId) }
        .sheet(isPresented: $notingBeforeSaving) { SavedCopiesNote(save: save) }
    }
}

/// Reporting a picture to the Host and Immerse's support (V2-FR-54): the reason only; the Host never learns who reported.
private struct ReportSheet: View {
    @Environment(\.groupFilms) private var groupFilms
    @Environment(\.dismiss) private var dismiss
    let eventID: String
    let pictureID: String

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(ReportReason.allCases, id: \.self) { reason in
                        Button(GroupReportReasonCopy.title(reason).capitalizedFirst) {
                            Task { if await groupFilms?.report(eventID, pictureID: pictureID, reason: reason) == true { dismiss() } }
                        }
                    }
                } footer: {
                    Text(reportFooter)
                }
            }
            .navigationTitle("Report This Picture").toolbarTitleDisplayMode(.inline)
        }
    }

    private var reportFooter: String {
        let address = groupFilms?.supportAddress.map { " You can also write to \($0)." } ?? ""
        return "The report goes to the Host and to Immerse's support, who answer within 48 hours. The Host does not learn who reported it, and nothing is removed until the Host or support removes it.\(address)"
    }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
