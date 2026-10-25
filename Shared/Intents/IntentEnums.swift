import AppIntents

/// Side and distance as App Intent parameters, for Siri and for the widget's buttons.
extension Side: AppEnum {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Side of the road"
    static let caseDisplayRepresentations: [Side: DisplayRepresentation] = [
        .left: "Left",
        .right: "Right",
        .unknown: "Not sure",
    ]
}

extension Distance: AppEnum {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Distance from the road"
    static let caseDisplayRepresentations: [Distance: DisplayRepresentation] = [
        .near: "Near",
        .far: "Far",
        .unknown: "Not sure",
    ]
}
