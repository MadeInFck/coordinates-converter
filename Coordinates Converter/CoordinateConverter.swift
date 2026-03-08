// CoordinateConverter.swift
// Coordinates Converter
//
// Coordinate conversion engine.
//
// Input formats  : DD, DMS, DDM, UTM, MGRS
// Output formats : DD, DMS, DDM, UTM, MGRS
// Datums         : WGS84, GRS80/RGF93, ED50
//
// Projected conversions (UTM/MGRS) use the selected datum's ellipsoid.
// Datum transformations use a Helmert 7-parameter model via ECEF (~1 m precision).

import Foundation

// MARK: - Datum

/// Reference ellipsoid with Helmert 7-parameter transformation to WGS84.
enum Datum: String, CaseIterable, Identifiable {
    case wgs84 = "WGS84"
    case grs80 = "GRS80 / RGF93"
    case ed50  = "ED50"

    var id: String { rawValue }

    // ── Ellipsoid parameters ─────────────────────────────────────────────────

    /// Semi-major axis a (metres)
    var semiMajorAxis: Double {
        switch self {
        case .wgs84: return 6_378_137.0
        case .grs80: return 6_378_137.0
        case .ed50:  return 6_378_388.0
        }
    }

    /// Inverse flattening 1/f
    var inverseFlattening: Double {
        switch self {
        case .wgs84: return 298.257_223_563
        case .grs80: return 298.257_222_101
        case .ed50:  return 297.0
        }
    }

    var flattening:          Double { 1.0 / inverseFlattening }
    var eccentricitySquared: Double { let f = flattening; return 2*f - f*f }
    var semiMinorAxis:       Double { semiMajorAxis * (1 - flattening) }

    // ── Helmert parameters datum → WGS84 (translations in metres, rotations in arc-seconds) ──

    /// (dX, dY, dZ, rX, rY, rZ, dS×10⁻⁶)  Source: IGN / EPSG
    var helmertToWGS84: (dX: Double, dY: Double, dZ: Double,
                         rX: Double, rY: Double, rZ: Double,
                         dS: Double) {
        switch self {
        case .wgs84: return (0, 0, 0, 0, 0, 0, 0)
        case .grs80: return (0, 0, 0, 0, 0, 0, 0)   // GRS80 ≈ WGS84
        case .ed50:  return (-87.0, -98.0, -121.0, 0.0, 0.0, 0.0, 0.0)  // EPSG:1311
        }
    }
}

// MARK: - Coordinate Format

/// Supported coordinate representation formats.
enum CoordinateFormat: String, CaseIterable, Identifiable {
    case dd   = "DD"
    case dms  = "DMS"
    case ddm  = "DDM"
    case utm  = "UTM"
    case mgrs = "MGRS"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dd:   return "Decimal Degrees"
        case .dms:  return "Degrees Minutes Seconds"
        case .ddm:  return "Degrees Decimal Minutes"
        case .utm:  return "UTM"
        case .mgrs: return "MGRS"
        }
    }

    var placeholder: String {
        switch self {
        case .dd:   return "48.856614, 2.352222"
        case .dms:  return #"48°51'23.81"N 2°21'07.99"E"#
        case .ddm:  return "48°51.397'N 2°21.132'E"
        case .utm:  return "31U 452484 5411719"
        case .mgrs: return "31UDQ 52484 11719"
        }
    }
}

// MARK: - Conversion Result

struct ConversionResult {
    let lat:   Double
    let lon:   Double
    let datum: Datum
    let dd:    String
    let dms:   String
    let ddm:   String
    let utm:   String
    let mgrs:  String
}

// MARK: - Errors

enum CoordinateError: LocalizedError {
    case invalidFormat
    case outOfRange
    case mgrsInvalid

    var errorDescription: String? {
        switch self {
        case .invalidFormat: return "Invalid coordinate format."
        case .outOfRange:    return "Coordinate out of valid range (lat ±90°, lon ±180°)."
        case .mgrsInvalid:   return "Invalid MGRS reference."
        }
    }
}

// MARK: - Conversion Engine

struct CoordinateConverter {

    // =========================================================================
    // MARK: Auto-detect parsing  (always returns WGS84 lat/lon)
    // =========================================================================

    /// Auto-detects format, returns (lat, lon) on the given `inputDatum`.
    static func parse(_ text: String, inputDatum: Datum = .wgs84) throws -> (lat: Double, lon: Double) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { throw CoordinateError.invalidFormat }

        if let r = parseMGRS(t, datum: inputDatum)    { return r }
        if let r = parseDMSPair(t)                    { return r }
        if let r = parseDDMPair(t)                    { return r }
        if let r = parseUTMText(t, datum: inputDatum) { return r }
        if let r = parseDDPair(t)                     { return r }

        throw CoordinateError.invalidFormat
    }

    // =========================================================================
    // MARK: Format-explicit parsing
    // =========================================================================

    /// Parse text in a specific format on a specific datum.
    /// Returns (lat, lon) in the coordinate system of `datum`.
    static func parseExplicit(_ text: String,
                               format: CoordinateFormat,
                               datum: Datum) throws -> (lat: Double, lon: Double) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { throw CoordinateError.invalidFormat }

        let result: (Double, Double)?
        switch format {
        case .dd:   result = parseDDPair(t)
        case .dms:  result = parseDMSPair(t)
        case .ddm:  result = parseDDMPair(t)
        case .utm:  result = parseUTMText(t, datum: datum)
        case .mgrs: result = parseMGRS(t, datum: datum)
        }

        guard let r = result else { throw CoordinateError.invalidFormat }
        return r
    }

    // ── DD ────────────────────────────────────────────────────────────────────
    // Accepts: "48.8566, 2.3522"  "48.8566N 2.3522E"  "-48.8566 -2.3522"
    static func parseDDPair(_ s: String) -> (Double, Double)? {
        let p = #"^(-?\d+(?:[.,]\d+)?)\s*°?\s*([NSns])?\s*[,;\s]\s*(-?\d+(?:[.,]\d+)?)\s*°?\s*([EWOewo])?$"#
        guard let regex = try? NSRegularExpression(pattern: p),
              let m = regex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) else { return nil }
        func g(_ i: Int) -> String { capture(m, in: s, at: i) }
        guard var lat = Double(g(1).replacingOccurrences(of: ",", with: ".")),
              var lon = Double(g(3).replacingOccurrences(of: ",", with: ".")) else { return nil }
        if g(2).uppercased() == "S" { lat = -lat }
        if ["W","O"].contains(g(4).uppercased()) { lon = -lon }
        return validated(lat, lon)
    }

    // ── DMS ───────────────────────────────────────────────────────────────────
    // Accepts: "48°51'23.8\"N 002°21'07.9\"E"  "48 51 23.8N 002 21 07.9E"
    static func parseDMSPair(_ s: String) -> (Double, Double)? {
        let p = #"(\d{1,3})\s*[°\s]\s*(\d{1,2})\s*['\s]\s*(\d{1,2}(?:[.,]\d+)?)\s*[\"″\s]?\s*([NSns])\s*[,;\s]?\s*(\d{1,3})\s*[°\s]\s*(\d{1,2})\s*['\s]\s*(\d{1,2}(?:[.,]\d+)?)\s*[\"″\s]?\s*([EWOewo])"#
        guard let regex = try? NSRegularExpression(pattern: p),
              let m = regex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) else { return nil }
        func g(_ i: Int) -> String { capture(m, in: s, at: i) }
        guard let latD = Double(g(1)), let latM = Double(g(2)),
              let latS = Double(g(3).replacingOccurrences(of: ",", with: ".")),
              let lonD = Double(g(5)), let lonM = Double(g(6)),
              let lonS = Double(g(7).replacingOccurrences(of: ",", with: ".")) else { return nil }
        var lat = latD + latM/60 + latS/3600
        var lon = lonD + lonM/60 + lonS/3600
        if g(4).uppercased() == "S" { lat = -lat }
        if ["W","O"].contains(g(8).uppercased()) { lon = -lon }
        return validated(lat, lon)
    }

    // ── DDM ───────────────────────────────────────────────────────────────────
    // Accepts: "48°51.397'N 002°21.132'E"
    static func parseDDMPair(_ s: String) -> (Double, Double)? {
        let p = #"(\d{1,3})\s*°\s*(\d{1,2}(?:[.,]\d+)?)\s*['\s]\s*([NSns])\s*[,;\s]?\s*(\d{1,3})\s*°\s*(\d{1,2}(?:[.,]\d+)?)\s*['\s]\s*([EWOewo])"#
        guard let regex = try? NSRegularExpression(pattern: p),
              let m = regex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) else { return nil }
        func g(_ i: Int) -> String { capture(m, in: s, at: i) }
        guard let latD = Double(g(1)),
              let latM = Double(g(2).replacingOccurrences(of: ",", with: ".")),
              let lonD = Double(g(4)),
              let lonM = Double(g(5).replacingOccurrences(of: ",", with: ".")) else { return nil }
        var lat = latD + latM/60
        var lon = lonD + lonM/60
        if g(3).uppercased() == "S" { lat = -lat }
        if ["W","O"].contains(g(6).uppercased()) { lon = -lon }
        return validated(lat, lon)
    }

    // ── UTM ───────────────────────────────────────────────────────────────────
    // Accepts: "31U 452484 5411719"  "31U 452484E 5411719N"
    static func parseUTMText(_ s: String, datum: Datum = .wgs84) -> (Double, Double)? {
        let p = #"(\d{1,2})\s*([C-HJ-NP-Xc-hj-np-x])\s+(\d{5,7})\s*[Ee]?\s+(\d{5,7})\s*[Nn]?"#
        guard let regex = try? NSRegularExpression(pattern: p),
              let m = regex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) else { return nil }
        func g(_ i: Int) -> String { capture(m, in: s, at: i) }
        guard let zone  = Int(g(1)),
              let east  = Double(g(3)),
              let north = Double(g(4)) else { return nil }
        let band    = g(2).uppercased()
        let isNorth = !"CDEFGHJKLM".contains(band)
        let (lat, lon) = utmToDD(zone: zone, easting: east, northing: north,
                                 isNorth: isNorth, datum: datum)
        return validated(lat, lon)
    }

    // ── MGRS ──────────────────────────────────────────────────────────────────
    // Accepts: "31UDQ5248411718"  "31U DQ 52484 11718"  "31UDQ 52484 11718"
    static func parseMGRS(_ s: String, datum: Datum = .wgs84) -> (Double, Double)? {
        let clean = s.replacingOccurrences(of: " ", with: "").uppercased()
        let p = #"^(\d{1,2})([C-HJ-NP-X])([A-HJ-NP-Z])([A-HJ-NP-V])(\d{4}|\d{6}|\d{8}|\d{10})$"#
        guard let regex = try? NSRegularExpression(pattern: p),
              let m = regex.firstMatch(in: clean, range: NSRange(clean.startIndex..., in: clean)) else { return nil }
        func g(_ i: Int) -> String { capture(m, in: clean, at: i) }
        guard let zone = Int(g(1)) else { return nil }
        let band = g(2); let colLetter = g(3); let rowLetter = g(4); let digits = g(5)

        let half = digits.count / 2
        guard let e100km = Int(String(digits.prefix(half))),
              let n100km = Int(String(digits.suffix(half))) else { return nil }

        // Resolution: 5 digits per coordinate = 1 m precision
        let resolution: Double
        switch digits.count {
        case 4:  resolution = 10_000
        case 6:  resolution = 1_000
        case 8:  resolution = 100
        case 10: resolution = 1
        default: resolution = 1
        }

        guard let (easting, northing) = mgrsToUTM(zone: zone, band: band,
                                                   colLetter: colLetter, rowLetter: rowLetter,
                                                   e100km: e100km, n100km: n100km,
                                                   resolution: resolution) else { return nil }
        let isNorth = !"CDEFGHJKLM".contains(band)
        let (lat, lon) = utmToDD(zone: zone, easting: easting, northing: northing,
                                 isNorth: isNorth, datum: datum)
        return validated(lat, lon)
    }

    // =========================================================================
    // MARK: Conversion — DD → all formats
    // =========================================================================

    /// Convert (lat, lon) in WGS84 to all formats on the target datum.
    static func convert(lat: Double, lon: Double, datum: Datum) throws -> ConversionResult {
        guard validated(lat, lon) != nil else { throw CoordinateError.outOfRange }
        let (tLat, tLon) = transformFromWGS84(lat: lat, lon: lon, to: datum)
        return makeResult(lat: tLat, lon: tLon, datum: datum)
    }

    /// Full pipeline: parse text in a given format/datum, convert to output datum.
    /// - Parameter text: Raw input string (or "zone easting northing" for UTM).
    /// - Parameter inputFormat: Format of the input text.
    /// - Parameter inputDatum: Reference datum of the input coordinates.
    /// - Parameter outputDatum: Target datum for all output representations.
    static func convert(text: String,
                        inputFormat: CoordinateFormat,
                        inputDatum: Datum,
                        outputDatum: Datum) throws -> ConversionResult {
        // Step 1: parse — returns (lat, lon) on inputDatum
        let (parsedLat, parsedLon) = try parseExplicit(text, format: inputFormat, datum: inputDatum)

        // Step 2: inputDatum → WGS84 (identity for WGS84/GRS80)
        let (wgsLat, wgsLon) = transformToWGS84(lat: parsedLat, lon: parsedLon, from: inputDatum)

        // Step 3: WGS84 → outputDatum
        let (outLat, outLon) = transformFromWGS84(lat: wgsLat, lon: wgsLon, to: outputDatum)

        guard validated(outLat, outLon) != nil else { throw CoordinateError.outOfRange }
        return makeResult(lat: outLat, lon: outLon, datum: outputDatum)
    }

    // =========================================================================
    // MARK: Formatters
    // =========================================================================

    static func formatDD(lat: Double, lon: Double) -> String {
        String(format: "%.6f° %@  %.6f° %@",
               abs(lat), lat >= 0 ? "N" : "S",
               abs(lon), lon >= 0 ? "E" : "W")
    }

    static func formatDMS(lat: Double, lon: Double) -> String {
        func split(_ v: Double) -> (Int, Int, Double) {
            let d = Int(abs(v))
            let mf = (abs(v) - Double(d)) * 60
            return (d, Int(mf), (mf - Double(Int(mf))) * 60)
        }
        let (ld,lm,ls) = split(lat)
        let (od,om,os) = split(lon)
        return String(format: "%d°%02d'%05.2f\" %@  %d°%02d'%05.2f\" %@",
                      ld, lm, ls, lat >= 0 ? "N" : "S",
                      od, om, os, lon >= 0 ? "E" : "W")
    }

    static func formatDDM(lat: Double, lon: Double) -> String {
        func split(_ v: Double) -> (Int, Double) {
            let d = Int(abs(v)); return (d, (abs(v) - Double(d)) * 60)
        }
        let (ld,lm) = split(lat)
        let (od,om) = split(lon)
        return String(format: "%d° %08.5f' %@  %d° %08.5f' %@",
                      ld, lm, lat >= 0 ? "N" : "S",
                      od, om, lon >= 0 ? "E" : "W")
    }

    // =========================================================================
    // MARK: Datum transformation (simplified Helmert 3D)
    // =========================================================================

    /// WGS84 → target datum geographic coordinates.
    static func transformFromWGS84(lat: Double, lon: Double, to datum: Datum) -> (Double, Double) {
        guard datum != .wgs84 && datum != .grs80 else { return (lat, lon) }
        var (x, y, z) = geographicToECEF(lat: lat, lon: lon, datum: .wgs84)
        let h = datum.helmertToWGS84
        let s = 1.0 - h.dS * 1e-6
        let rX = h.rX * .pi / (180 * 3600)
        let rY = h.rY * .pi / (180 * 3600)
        let rZ = h.rZ * .pi / (180 * 3600)
        let xT = x; let yT = y; let zT = z
        x = (xT - h.dX) / s + rZ * (yT - h.dY) / s - rY * (zT - h.dZ) / s
        y = -rZ * (xT - h.dX) / s + (yT - h.dY) / s + rX * (zT - h.dZ) / s
        z = rY * (xT - h.dX) / s - rX * (yT - h.dY) / s + (zT - h.dZ) / s
        return ecefToGeographic(x: x, y: y, z: z, datum: datum)
    }

    /// Source datum geographic coordinates → WGS84.
    static func transformToWGS84(lat: Double, lon: Double, from datum: Datum) -> (Double, Double) {
        guard datum != .wgs84 && datum != .grs80 else { return (lat, lon) }
        var (x, y, z) = geographicToECEF(lat: lat, lon: lon, datum: datum)
        let h = datum.helmertToWGS84
        let s = 1.0 + h.dS * 1e-6
        let rX = h.rX * .pi / (180 * 3600)
        let rY = h.rY * .pi / (180 * 3600)
        let rZ = h.rZ * .pi / (180 * 3600)
        let xT = x; let yT = y; let zT = z
        x = h.dX + s * (xT       - rZ * yT + rY * zT)
        y = h.dY + s * (rZ * xT  + yT      - rX * zT)
        z = h.dZ + s * (-rY * xT + rX * yT + zT)
        return ecefToGeographic(x: x, y: y, z: z, datum: .wgs84)
    }

    private static func geographicToECEF(lat: Double, lon: Double, datum: Datum) -> (Double, Double, Double) {
        let a  = datum.semiMajorAxis
        let e2 = datum.eccentricitySquared
        let φ  = lat * .pi / 180
        let λ  = lon * .pi / 180
        let N  = a / sqrt(1 - e2 * sin(φ) * sin(φ))
        return (N * cos(φ) * cos(λ), N * cos(φ) * sin(λ), N * (1 - e2) * sin(φ))
    }

    private static func ecefToGeographic(x: Double, y: Double, z: Double, datum: Datum) -> (Double, Double) {
        let a  = datum.semiMajorAxis
        let b  = datum.semiMinorAxis
        let e2 = datum.eccentricitySquared
        let ep2 = (a*a - b*b) / (b*b)
        let p  = sqrt(x*x + y*y)
        let θ  = atan2(z * a, p * b)
        let φ  = atan2(z + ep2 * b * pow(sin(θ), 3),
                       p - e2  * a * pow(cos(θ), 3))
        let λ  = atan2(y, x)
        return (φ * 180 / .pi, λ * 180 / .pi)
    }

    // =========================================================================
    // MARK: UTM
    // =========================================================================

    static func calcUTM(lat: Double, lon: Double, datum: Datum) -> (String, Int, String, Double, Double) {
        let (zone, band, e, n) = ddToUTM(lat: lat, lon: lon, datum: datum)
        let str = String(format: "%d%@ %07d %07d", zone, band, Int(e.rounded()), Int(n.rounded()))
        return (str, zone, band, e, n)
    }

    static func ddToUTM(lat: Double, lon: Double, datum: Datum) -> (zone: Int, band: String, easting: Double, northing: Double) {
        let a  = datum.semiMajorAxis
        let e2 = datum.eccentricitySquared
        let k0 = 0.9996
        let φ = lat * .pi / 180
        let λ = lon * .pi / 180

        var zone = Int((lon + 180) / 6) + 1
        if lat >= 56 && lat < 64 && lon >= 3  && lon < 12 { zone = 32 }
        if lat >= 72 && lat < 84 {
            if      lon >= 0  && lon < 9  { zone = 31 }
            else if lon >= 9  && lon < 21 { zone = 33 }
            else if lon >= 21 && lon < 33 { zone = 35 }
            else if lon >= 33 && lon < 42 { zone = 37 }
        }
        let λ0 = Double((zone - 1) * 6 - 180 + 3) * .pi / 180

        let e4 = e2*e2; let e6 = e4*e2
        let N  = a / sqrt(1 - e2 * sin(φ) * sin(φ))
        let T  = tan(φ) * tan(φ)
        let C  = e2 / (1-e2) * cos(φ) * cos(φ)
        let A  = cos(φ) * (λ - λ0)
        let M  = a * (
              (1 - e2/4 - 3*e4/64 - 5*e6/256)  * φ
            - (3*e2/8 + 3*e4/32 + 45*e6/1024)  * sin(2*φ)
            + (15*e4/256 + 45*e6/1024)          * sin(4*φ)
            - (35*e6/3072)                       * sin(6*φ)
        )
        let easting = k0*N*(A + (1-T+C)*pow(A,3)/6
            + (5-18*T+T*T+72*C-58*e2/(1-e2))*pow(A,5)/120) + 500_000.0
        var northing = k0*(M + N*tan(φ)*(A*A/2
            + (5-T+9*C+4*C*C)*pow(A,4)/24
            + (61-58*T+T*T+600*C-330*e2/(1-e2))*pow(A,6)/720))
        if lat < 0 { northing += 10_000_000.0 }
        return (zone, utmBand(lat), easting, northing)
    }

    static func utmToDD(zone: Int, easting: Double, northing: Double, isNorth: Bool, datum: Datum) -> (Double, Double) {
        let a  = datum.semiMajorAxis
        let e2 = datum.eccentricitySquared
        let k0 = 0.9996
        let e1 = (1 - sqrt(1-e2)) / (1 + sqrt(1-e2))
        let x  = easting - 500_000.0
        let y  = isNorth ? northing : northing - 10_000_000.0
        let λ0 = Double((zone-1)*6 - 180 + 3) * .pi / 180
        let e4 = e2*e2; let e6 = e4*e2
        let M   = y / k0
        let mu  = M / (a*(1 - e2/4 - 3*e4/64 - 5*e6/256))
        let φ1  = mu
            + (3*e1/2    - 27*e1*e1*e1/32)    * sin(2*mu)
            + (21*e1*e1/16 - 55*pow(e1,4)/32) * sin(4*mu)
            + (151*pow(e1,3)/96)               * sin(6*mu)
            + (1097*pow(e1,4)/512)             * sin(8*mu)
        let N1 = a / sqrt(1 - e2*sin(φ1)*sin(φ1))
        let T1 = tan(φ1)*tan(φ1)
        let C1 = e2/(1-e2)*cos(φ1)*cos(φ1)
        let R1 = a*(1-e2) / pow(1 - e2*sin(φ1)*sin(φ1), 1.5)
        let D  = x / (N1*k0)
        let φ = φ1 - N1*tan(φ1)/R1*(D*D/2
            - (5+3*T1+10*C1-4*C1*C1-9*e4/e2)*pow(D,4)/24
            + (61+90*T1+298*C1+45*T1*T1-252*e4/e2-3*C1*C1)*pow(D,6)/720)
        let λ = λ0 + (D - (1+2*T1+C1)*pow(D,3)/6
            + (5-2*C1+28*T1-3*C1*C1+8*e4/e2+24*T1*T1)*pow(D,5)/120) / cos(φ1)
        return (φ * (180 / .pi), λ * (180 / .pi))
    }

    private static func utmBand(_ lat: Double) -> String {
        let b = "CDEFGHJKLMNPQRSTUVWXX"
        let i = max(0, min(b.count-1, Int((lat + 80) / 8)))
        return String(b[b.index(b.startIndex, offsetBy: i)])
    }

    // =========================================================================
    // MARK: MGRS
    // =========================================================================

    static func calcMGRS(zone: Int, band: String, easting: Double, northing: Double) -> String {
        let colSets = ["ABCDEFGH", "JKLMNPQR", "STUVWXYZ"]
        let rowSets = ["ABCDEFGHJKLMNPQRSTUV", "FGHJKLMNPQRSTUVABCDE"]
        let setIdx    = (zone - 1) % 3
        let colOffset = Int(easting / 100_000) - 1
        let rowOffset = Int(northing / 100_000) % 20
        let colSet    = colSets[setIdx]
        let rowSet    = rowSets[(zone - 1) % 2]
        guard colOffset >= 0, colOffset < colSet.count,
              rowOffset >= 0, rowOffset < rowSet.count else { return "—" }
        let colLetter = String(colSet[colSet.index(colSet.startIndex, offsetBy: colOffset)])
        let rowLetter = String(rowSet[rowSet.index(rowSet.startIndex, offsetBy: rowOffset)])
        let e5 = Int(easting.truncatingRemainder(dividingBy: 100_000))
        let n5 = Int(northing.truncatingRemainder(dividingBy: 100_000))
        return String(format: "%d%@%@%@ %05d %05d", zone, band, colLetter, rowLetter, e5, n5)
    }

    private static func mgrsToUTM(zone: Int, band: String,
                                   colLetter: String, rowLetter: String,
                                   e100km: Int, n100km: Int,
                                   resolution: Double) -> (Double, Double)? {
        let colSets = ["ABCDEFGH", "JKLMNPQR", "STUVWXYZ"]
        let rowSets = ["ABCDEFGHJKLMNPQRSTUV", "FGHJKLMNPQRSTUVABCDE"]
        let colSet  = colSets[(zone - 1) % 3]
        let rowSet  = rowSets[(zone - 1) % 2]
        guard let colIdx = colSet.firstIndex(of: colLetter.first!),
              let rowIdx = rowSet.firstIndex(of: rowLetter.first!) else { return nil }
        let colNum = colSet.distance(from: colSet.startIndex, to: colIdx) + 1
        let rowNum = rowSet.distance(from: rowSet.startIndex, to: rowIdx)
        let easting  = Double(colNum) * 100_000.0 + Double(e100km) * resolution
        let bandCenter   = centerNorthingFor(band: band)
        let baseNorthing = Double(rowNum) * 100_000.0 + Double(n100km) * resolution
        let cycle    = 2_000_000.0
        let k        = (bandCenter - baseNorthing) / cycle
        let northing = baseNorthing + cycle * floor(k + 0.5)
        return (easting, northing)
    }

    private static func centerNorthingFor(band: String) -> Double {
        let table: [String: Double] = [
            "C": 1_600_000, "D": 2_400_000, "E": 3_200_000, "F": 4_100_000,
            "G": 5_000_000, "H": 5_800_000, "J": 6_700_000, "K": 7_600_000,
            "L": 8_500_000, "M": 9_300_000,
            "N": 400_000,   "P": 1_200_000, "Q": 2_100_000, "R": 3_000_000,
            "S": 3_900_000, "T": 4_800_000, "U": 5_400_000, "V": 6_300_000,
            "W": 7_200_000, "X": 8_400_000
        ]
        return table[band] ?? 5_000_000
    }

    // =========================================================================
    // MARK: Private helpers
    // =========================================================================

    private static func makeResult(lat: Double, lon: Double, datum: Datum) -> ConversionResult {
        let (utmStr, zone, band, e, n) = calcUTM(lat: lat, lon: lon, datum: datum)
        return ConversionResult(
            lat: lat, lon: lon, datum: datum,
            dd:   formatDD(lat: lat, lon: lon),
            dms:  formatDMS(lat: lat, lon: lon),
            ddm:  formatDDM(lat: lat, lon: lon),
            utm:  utmStr,
            mgrs: calcMGRS(zone: zone, band: band, easting: e, northing: n)
        )
    }

    private static func validated(_ lat: Double, _ lon: Double) -> (Double, Double)? {
        guard lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180 else { return nil }
        return (lat, lon)
    }

    private static func capture(_ match: NSTextCheckingResult, in s: String, at i: Int) -> String {
        guard let r = Range(match.range(at: i), in: s) else { return "" }
        return String(s[r])
    }
}
