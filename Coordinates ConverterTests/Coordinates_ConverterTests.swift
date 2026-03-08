// Coordinates_ConverterTests.swift
// Coordinates ConverterTests
//
// Unit tests for the CoordinateConverter engine.
// Reference values: IGN, EPSG Geodesy, cross-checked with proj4/pyproj.

import Testing
@testable import Coordinates_Converter

private let angularTolerance = 1e-5   // ~1 m in degrees
private let metricTolerance  = 1.0    // ±1 m

// MARK: - Formatters

@Suite("Formatters DD / DMS / DDM")
struct FormatterTests {

    @Test("DD format — Paris")
    func formatDD() {
        let s = CoordinateConverter.formatDD(lat: 48.856_614, lon: 2.352_222)
        #expect(s.contains("48.856614"))
        #expect(s.contains("2.352222"))
        #expect(s.contains("N"))
        #expect(s.contains("E"))
    }

    @Test("DD format — southern hemisphere")
    func formatDDSouth() {
        let s = CoordinateConverter.formatDD(lat: -33.8688, lon: -70.6693)
        #expect(s.contains("S"))
        #expect(s.contains("W"))
    }

    @Test("DMS format — Paris")
    func formatDMS() {
        let s = CoordinateConverter.formatDMS(lat: 48.856_614, lon: 2.352_222)
        #expect(s.contains("48°"))
        #expect(s.contains("51'"))
        #expect(s.contains("2°"))
        #expect(s.contains("21'"))
    }

    @Test("DDM format — Paris")
    func formatDDM() {
        let s = CoordinateConverter.formatDDM(lat: 48.856_614, lon: 2.352_222)
        #expect(s.contains("48°"))
        #expect(s.contains("2°"))
        #expect(s.contains("N"))
        #expect(s.contains("E"))
    }
}

// MARK: - Auto-detect parsing

@Suite("Auto-detect parsing")
struct ParsingTests {

    @Test("Parse DD comma-separated")
    func parseDDComma() throws {
        let (lat, lon) = try CoordinateConverter.parse("48.856614, 2.352222")
        #expect(abs(lat - 48.856614) < angularTolerance)
        #expect(abs(lon - 2.352222)  < angularTolerance)
    }

    @Test("Parse DD with cardinal indicators")
    func parseDDCardinal() throws {
        let (lat, lon) = try CoordinateConverter.parse("48.856614N 2.352222E")
        #expect(abs(lat - 48.856614) < angularTolerance)
        #expect(abs(lon - 2.352222)  < angularTolerance)
    }

    @Test("Parse DD negative (S/W)")
    func parseDDNeg() throws {
        let (lat, lon) = try CoordinateConverter.parse("-33.8688, -70.6693")
        #expect(lat < 0)
        #expect(lon < 0)
    }

    @Test("Parse DMS standard")
    func parseDMS() throws {
        let (lat, lon) = try CoordinateConverter.parse(#"48°51'23.81"N 2°21'07.99"E"#)
        #expect(abs(lat - 48.856614) < 1e-4)
        #expect(abs(lon - 2.352220)  < 1e-4)
    }

    @Test("Parse DMS — southern hemisphere")
    func parseDMSSouth() throws {
        let (lat, _) = try CoordinateConverter.parse(#"33°52'07.68"S 70°40'09.48"W"#)
        #expect(lat < 0)
    }

    @Test("Parse DDM")
    func parseDDM() throws {
        let (lat, lon) = try CoordinateConverter.parse("48°51.397'N 2°21.132'E")
        #expect(abs(lat - 48.856617) < 1e-4)
        #expect(abs(lon - 2.352200)  < 1e-4)
    }

    @Test("Parse UTM — Paris")
    func parseUTM() throws {
        let (lat, lon) = try CoordinateConverter.parse("31U 452484 5411719")
        #expect(abs(lat - 48.856614) < 1e-3)
        #expect(abs(lon - 2.352222)  < 1e-3)
    }

    @Test("Parse MGRS — Paris (1 m)")
    func parseMGRS() throws {
        let (lat, lon) = try CoordinateConverter.parse("31UDQ5248411718")
        #expect(abs(lat - 48.856) < 0.01)
        #expect(abs(lon - 2.352)  < 0.01)
    }

    @Test("Error on empty input")
    func parseEmpty() {
        #expect(throws: CoordinateError.self) {
            try CoordinateConverter.parse("")
        }
    }

    @Test("Error on invalid text")
    func parseGarbage() {
        #expect(throws: CoordinateError.self) {
            try CoordinateConverter.parse("hello world")
        }
    }
}

// MARK: - Explicit format parsing

@Suite("Explicit format parsing (parseExplicit)")
struct ExplicitParseTests {

    @Test("parseExplicit DD")
    func parseExplicitDD() throws {
        let (lat, lon) = try CoordinateConverter.parseExplicit(
            "48.856614, 2.352222", format: .dd, datum: .wgs84)
        #expect(abs(lat - 48.856614) < angularTolerance)
        #expect(abs(lon - 2.352222)  < angularTolerance)
    }

    @Test("parseExplicit DMS")
    func parseExplicitDMS() throws {
        let (lat, lon) = try CoordinateConverter.parseExplicit(
            #"48°51'23.81"N 2°21'07.99"E"#, format: .dms, datum: .wgs84)
        #expect(abs(lat - 48.856614) < 1e-4)
        #expect(abs(lon - 2.352220)  < 1e-4)
    }

    @Test("parseExplicit DDM")
    func parseExplicitDDM() throws {
        let (lat, lon) = try CoordinateConverter.parseExplicit(
            "48°51.397'N 2°21.132'E", format: .ddm, datum: .wgs84)
        #expect(abs(lat - 48.856617) < 1e-4)
        #expect(abs(lon - 2.352200)  < 1e-4)
    }

    @Test("parseExplicit UTM WGS84")
    func parseExplicitUTM() throws {
        let (lat, lon) = try CoordinateConverter.parseExplicit(
            "31U 452484 5411719", format: .utm, datum: .wgs84)
        #expect(abs(lat - 48.856614) < 1e-3)
        #expect(abs(lon - 2.352222)  < 1e-3)
    }

    @Test("parseExplicit MGRS WGS84")
    func parseExplicitMGRS() throws {
        let (lat, lon) = try CoordinateConverter.parseExplicit(
            "31UDQ5248411718", format: .mgrs, datum: .wgs84)
        #expect(abs(lat - 48.856) < 0.01)
        #expect(abs(lon - 2.352)  < 0.01)
    }

    @Test("Wrong format throws invalidFormat")
    func wrongFormatThrows() {
        #expect(throws: CoordinateError.self) {
            try CoordinateConverter.parseExplicit(
                "48.856614, 2.352222", format: .utm, datum: .wgs84)
        }
    }

    @Test("parseExplicit UTM with ED50 datum — round-trip")
    func parseUTMWithED50() throws {
        let (ed50Lat, ed50Lon) = CoordinateConverter.transformFromWGS84(
            lat: 48.856614, lon: 2.352222, to: .ed50)
        let (_, _, easting, northing) = CoordinateConverter.ddToUTM(
            lat: ed50Lat, lon: ed50Lon, datum: .ed50)
        let utmText = "31U \(Int(easting)) \(Int(northing))"
        let (lat, lon) = try CoordinateConverter.parseExplicit(
            utmText, format: .utm, datum: .ed50)
        #expect(abs(lat - ed50Lat) < 1e-3)
        #expect(abs(lon - ed50Lon) < 1e-3)
    }
}

// MARK: - CoordinateFormat enum

@Suite("CoordinateFormat enum")
struct CoordinateFormatTests {

    @Test("All 5 cases exist")
    func allCases() {
        #expect(CoordinateFormat.allCases.count == 5)
    }

    @Test("Display names are non-empty")
    func displayNames() {
        for format in CoordinateFormat.allCases {
            #expect(!format.displayName.isEmpty)
        }
    }

    @Test("Placeholders are non-empty")
    func placeholders() {
        for format in CoordinateFormat.allCases {
            #expect(!format.placeholder.isEmpty)
        }
    }
}

// MARK: - Full pipeline (text + inputDatum → outputDatum)

@Suite("Full conversion pipeline")
struct FullPipelineTests {

    @Test("WGS84 DD → WGS84 all formats")
    func pipelineWGS84toWGS84() throws {
        let r = try CoordinateConverter.convert(
            text: "48.856614, 2.352222",
            inputFormat: .dd, inputDatum: .wgs84, outputDatum: .wgs84)
        #expect(abs(r.lat - 48.856614) < angularTolerance)
        #expect(r.utm.contains("31U"))
        #expect(r.mgrs.contains("31U"))
    }

    @Test("WGS84 UTM → WGS84 all formats")
    func pipelineUTMtoWGS84() throws {
        let r = try CoordinateConverter.convert(
            text: "31U 452484 5411719",
            inputFormat: .utm, inputDatum: .wgs84, outputDatum: .wgs84)
        #expect(abs(r.lat - 48.856) < 0.01)
        #expect(abs(r.lon - 2.352)  < 0.01)
    }

    @Test("WGS84 MGRS → WGS84 all formats")
    func pipelineMGRStoWGS84() throws {
        let r = try CoordinateConverter.convert(
            text: "31UDQ5248411718",
            inputFormat: .mgrs, inputDatum: .wgs84, outputDatum: .wgs84)
        #expect(abs(r.lat - 48.856) < 0.01)
        #expect(abs(r.lon - 2.352)  < 0.01)
    }

    @Test("ED50 DD → WGS84 (datum shift applied)")
    func pipelineED50toWGS84() throws {
        // Build ED50 coordinates for Paris
        let (ed50Lat, ed50Lon) = CoordinateConverter.transformFromWGS84(
            lat: 48.856614, lon: 2.352222, to: .ed50)
        let input = String(format: "%.6f, %.6f", ed50Lat, ed50Lon)
        let r = try CoordinateConverter.convert(
            text: input, inputFormat: .dd, inputDatum: .ed50, outputDatum: .wgs84)
        #expect(abs(r.lat - 48.856614) < 1e-4)
        #expect(abs(r.lon - 2.352222)  < 1e-4)
    }

    @Test("Out-of-range throws outOfRange")
    func pipelineOutOfRange() {
        #expect(throws: CoordinateError.self) {
            try CoordinateConverter.convert(
                text: "95.0, 0.0", inputFormat: .dd, inputDatum: .wgs84, outputDatum: .wgs84)
        }
    }
}

// MARK: - UTM projection

@Suite("UTM projection")
struct UTMTests {

    @Test("DD → UTM → DD round-trip (Paris, WGS84)")
    func roundTripParis() {
        let lat = 48.856_614; let lon = 2.352_222
        let (zone, _, e, n) = CoordinateConverter.ddToUTM(lat: lat, lon: lon, datum: .wgs84)
        let (lat2, lon2) = CoordinateConverter.utmToDD(zone: zone, easting: e, northing: n,
                                                       isNorth: true, datum: .wgs84)
        #expect(abs(lat2 - lat) < angularTolerance)
        #expect(abs(lon2 - lon) < angularTolerance)
    }

    @Test("DD → UTM → DD round-trip (Sydney, WGS84)")
    func roundTripSydney() {
        let lat = -33.8688; let lon = 151.2093
        let (zone, _, e, n) = CoordinateConverter.ddToUTM(lat: lat, lon: lon, datum: .wgs84)
        let (lat2, lon2) = CoordinateConverter.utmToDD(zone: zone, easting: e, northing: n,
                                                       isNorth: false, datum: .wgs84)
        #expect(abs(lat2 - lat) < angularTolerance)
        #expect(abs(lon2 - lon) < angularTolerance)
    }

    @Test("UTM zone — Paris = 31U")
    func zoneUTMParis() {
        let (zone, band, _, _) = CoordinateConverter.ddToUTM(lat: 48.856614, lon: 2.352222, datum: .wgs84)
        #expect(zone == 31)
        #expect(band == "U")
    }

    @Test("UTM zone — Norway exception (zone 32)")
    func zoneNorwayException() {
        let (zone, _, _, _) = CoordinateConverter.ddToUTM(lat: 60.4, lon: 5.3, datum: .wgs84)
        #expect(zone == 32)
    }
}

// MARK: - Datum transformation

@Suite("Datum transformation")
struct DatumTransformTests {

    @Test("WGS84 → ED50 → WGS84 round-trip (Paris)")
    func roundTripED50() {
        let lat = 48.856_614; let lon = 2.352_222
        let (tLat, tLon) = CoordinateConverter.transformFromWGS84(lat: lat, lon: lon, to: .ed50)
        let (bLat, bLon) = CoordinateConverter.transformToWGS84(lat: tLat, lon: tLon, from: .ed50)
        #expect(abs(bLat - lat) < 1e-4)
        #expect(abs(bLon - lon) < 1e-4)
    }

    @Test("WGS84 and GRS80 are equivalent")
    func wgs84GRS80Equivalence() {
        let lat = 48.856_614; let lon = 2.352_222
        let (tLat, tLon) = CoordinateConverter.transformFromWGS84(lat: lat, lon: lon, to: .grs80)
        #expect(tLat == lat)
        #expect(tLon == lon)
    }

    @Test("ED50 offset ~100 m from WGS84 in Paris")
    func ed50OffsetParis() {
        let lat = 48.856_614; let lon = 2.352_222
        let (tLat, tLon) = CoordinateConverter.transformFromWGS84(lat: lat, lon: lon, to: .ed50)
        #expect(abs(tLat - lat) > 1e-5)   // must differ
        #expect(abs(tLat - lat) < 0.01)   // but not more than ~1 km
        #expect(abs(tLon - lon) < 0.01)
    }
}

// MARK: - convert(lat:lon:datum:) legacy API

@Suite("Legacy convert(lat:lon:datum:)")
struct ConvertTests {

    @Test("Paris WGS84")
    func convertParis() throws {
        let r = try CoordinateConverter.convert(lat: 48.856614, lon: 2.352222, datum: .wgs84)
        #expect(r.dd.contains("48"))
        #expect(r.dms.contains("51'"))
        #expect(r.utm.contains("31U"))
        #expect(r.mgrs.contains("31U"))
    }

    @Test("Out-of-range throws outOfRange")
    func convertOutOfRange() {
        #expect(throws: CoordinateError.self) {
            try CoordinateConverter.convert(lat: 95, lon: 0, datum: .wgs84)
        }
    }
}
