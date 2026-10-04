/// What a public inquiry is about (club_server#407, #35).
enum InquiryKind {
  /// A general contact-form message.
  contact('contact'),

  /// An expression of interest in a programme or camp.
  interest('interest');

  const InquiryKind(this.wireName);

  final String wireName;

  static InquiryKind fromWire(String wire) {
    for (final v in InquiryKind.values) {
      if (v.wireName == wire) return v;
    }
    return InquiryKind.contact;
  }
}
