import SwiftUI
import MapKit

/// 기관 찾기 — 안과 / 안경점 / 라식 병원 검색. 지도 + 리스트.
/// GET /api/mobile/hospitals/search 연동.
struct HospitalFinderView: View {
    @StateObject private var location = LocationProvider()

    @State private var type: PlaceType = .clinic
    @State private var query = ""
    @State private var places: [HospitalPlace] = []
    @State private var loading = false
    @State private var error: String?
    @State private var camera: MapCameraPosition = .region(
        MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780),
                           span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)))

    private var mappable: [HospitalPlace] {
        places.filter { $0.lat != nil && $0.lng != nil }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                typePicker
                searchField

                if !mappable.isEmpty {
                    Map(position: $camera) {
                        UserAnnotation()
                        ForEach(mappable) { place in
                            Marker(place.name,
                                   systemImage: place.type.symbol,
                                   coordinate: CLLocationCoordinate2D(latitude: place.lat!, longitude: place.lng!))
                        }
                    }
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }

                resultsList
            }
            .navigationTitle("finder.title")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                location.request()
                await search()
            }
            .onChange(of: type) { _, _ in Task { await search() } }
            .onChange(of: location.coordinate?.latitude) { _, _ in Task { await search() } }
        }
    }

    private var typePicker: some View {
        Picker("finder.type", selection: $type) {
            ForEach(PlaceType.allCases) { t in
                Text(LocalizedStringKey(t.titleKey)).tag(t)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 10)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("finder.search.placeholder", text: $query)
                .textFieldStyle(.plain)
                .onSubmit { Task { await search() } }
            if !query.isEmpty {
                Button { query = ""; Task { await search() } } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 9).padding(.horizontal, 12)
        .background(Color(.secondarySystemBackground), in: Capsule())
        .padding(.horizontal, 16).padding(.bottom, 10)
    }

    @ViewBuilder private var resultsList: some View {
        if loading && places.isEmpty {
            Spacer(); ProgressView(); Spacer()
        } else if let error {
            Spacer()
            VStack(spacing: 8) {
                Text("finder.loadFail").font(.headline)
                Text(error).font(.caption).foregroundStyle(.secondary)
                Button("children.retry") { Task { await search() } }
            }
            Spacer()
        } else if places.isEmpty {
            Spacer()
            ContentUnavailableView {
                Label("finder.empty.title", systemImage: type.symbol)
            } description: {
                Text("finder.empty.body")
            }
            Spacer()
        } else {
            List(places) { place in
                PlaceRow(place: place)
            }
            .listStyle(.plain)
            .refreshable { await search() }
        }
    }

    private func search() async {
        loading = true; defer { loading = false }
        error = nil
        do {
            let resp: HospitalSearchResponse = try await APIClient.shared.send(
                .hospitalSearch(type: type,
                                query: query,
                                lat: location.coordinate?.latitude,
                                lng: location.coordinate?.longitude))
            places = resp.places
            recenter()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func recenter() {
        if let c = location.coordinate {
            camera = .region(MKCoordinateRegion(center: c,
                span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)))
        } else if let first = mappable.first, let lat = first.lat, let lng = first.lng {
            camera = .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)))
        }
    }
}

private struct PlaceRow: View {
    let place: HospitalPlace

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: place.type.symbol)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 42, height: 42)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(place.name).font(.subheadline.weight(.semibold))
                    if place.isPartner {
                        Text("finder.partner")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Color.green.opacity(0.15), in: Capsule())
                            .foregroundStyle(.green)
                    }
                }
                if let address = place.address {
                    Text(address).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                HStack(spacing: 10) {
                    if let rating = place.rating {
                        Label(String(format: "%.1f", rating), systemImage: "star.fill")
                            .font(.caption2).foregroundStyle(.orange)
                    }
                    if let d = place.distanceKm {
                        Text(String(format: "%.1fkm", d))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            if let phone = place.phone, let url = URL(string: "tel://\(phone.filter { $0.isNumber })") {
                Link(destination: url) {
                    Image(systemName: "phone.fill").foregroundStyle(Color.accentColor)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    HospitalFinderView()
}
