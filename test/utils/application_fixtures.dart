/// Application template payloads for the unit tests (#66, club_server#93).
///
/// [applicationContentJson] is the content an admin sends, in the shape of
/// club_server's own `tests/application_helpers.py::template_body`: English
/// and Marathi, every kind of fact (kept for the editor, never printed),
/// printed texts as `{language: text}` only (club_server#107), a header
/// line of two texts, terms with a heading and a body, and a note with an
/// attribution. It is fictional and club-neutral.
library;

/// A calendar date as the API sends it: UTC midnight, in ms.
int day(int y, int m, int d) => DateTime.utc(y, m, d).millisecondsSinceEpoch;

/// The content of a complete English + Marathi template.
Map<String, dynamic> applicationContentJson() => <String, dynamic>{
  'languages': ['en', 'mr'],
  'facts': <String, dynamic>{
    'venue': {
      'type': 'name',
      'value': {'en': 'City Rink', 'mr': 'सिटी रिंक'},
    },
    'phone': {'type': 'name', 'value': '98765 43210'},
    'camp': {
      'type': 'date_range',
      'from': day(2026, 11, 16),
      'to': day(2026, 11, 17),
    },
    'matches': {
      'type': 'date_range',
      'from': day(2026, 11, 19),
      'to': day(2026, 11, 21),
    },
    'trialDay': {'type': 'date', 'value': day(2026, 11, 18)},
    'reporting': {'type': 'time', 'value': '6:30'},
    'fee': {'type': 'amount', 'value': 150000},
    'surface': {
      'type': 'choices',
      'value': ['on_ice', 'inline'],
    },
  },
  'organisation': {'en': 'EXAMPLE CLUB', 'mr': 'उदाहरण क्लब'},
  'title': {
    'en': 'Selection Trial — Registration Form',
    'mr': 'निवड चाचणी — नोंदणी अर्ज',
  },
  'subtitle': {'en': '16–17 November 2026', 'mr': '16–17 नोव्हेंबर 2026'},
  'header': [
    {'en': 'City Rink', 'mr': 'सिटी रिंक'},
    [
      {
        'en': 'Training camp: 16–17 November 2026',
        'mr': 'प्रशिक्षण शिबिर: 16–17 नोव्हेंबर 2026',
      },
      {
        'en': 'Matches: 19–21 November 2026',
        'mr': 'सामने: 19–21 नोव्हेंबर 2026',
      },
    ],
    {'en': '98765 43210'},
  ],
  'ageCategories': [
    {
      'label': {'en': 'Under-12', 'mr': 'अंडर-12'},
      'bornOnOrAfterUtc': day(2014, 1, 1),
    },
    {
      'label': {'en': 'Under-15 Girls', 'mr': 'अंडर-15 मुली'},
      'bornOnOrAfterUtc': day(2011, 1, 1),
      'bornOnOrBeforeUtc': day(2013, 12, 31),
      'genders': ['female', 'prefer_not_to_say'],
    },
  ],
  'selections': [
    {
      'en': 'I will attend the training camp on 16–17 November 2026.',
      'mr': 'मी 16–17 नोव्हेंबर 2026 रोजीच्या प्रशिक्षण शिबिरास उपस्थित राहीन.',
    },
  ],
  'declaration': {
    'en': 'I agree to abide by the rules of the trial.',
    'mr': 'मी चाचणीचे नियम पाळण्यास सहमत आहे.',
  },
  'formFooter': {'en': 'Play fair, play hard.', 'mr': 'खिलाडूवृत्तीने खेळा.'},
  'terms': [
    {
      'heading': {'en': 'Identity proof', 'mr': 'ओळखपत्र'},
      'body': {
        'en': 'Bring a proof of identity.',
        'mr': 'ओळखपत्र सोबत आणा.',
      },
    },
    {
      'heading': {'en': 'Kit', 'mr': 'साहित्य'},
      'body': {'en': 'Bring your own helmet.', 'mr': 'स्वतःचे हेल्मेट आणा.'},
    },
  ],
  'termsNotes': [
    {
      'text': {'en': 'Follow the rules.', 'mr': 'नियम पाळा.'},
      'attribution': {'en': '— Example Club'},
    },
    {
      'text': {'en': 'See you on the ice.', 'mr': 'मैदानावर भेटू.'},
    },
  ],
  'labelOverrides': {
    'field.past_experience': {
      'en': 'Past experience — any skating sport',
      'mr': 'पूर्व अनुभव',
    },
  },
};

/// A saved template as `GET /v1/applications/{id}` returns it.
Map<String, dynamic> applicationResponseJson({
  int id = 7,
  String status = 'saved',
}) => <String, dynamic>{
  ...applicationContentJson(),
  'id': id,
  'status': status,
  'layout': {
    'name': 'one page',
    'spread': {'withGuardian': 3.25, 'withoutGuardian': 6.5},
  },
  'fittingCategories': null,
  'publishId': null,
  'createdBy': 'test_admin',
  'createdAtUtc': 1767225600000,
  'updatedAtUtc': 1767229200000,
};

/// A new draft with nothing filled in, as the server returns it.
Map<String, dynamic> emptyDraftResponseJson({int id = 8}) => <String, dynamic>{
  'languages': ['en'],
  'facts': <String, dynamic>{},
  'organisation': null,
  'title': null,
  'subtitle': null,
  'header': <dynamic>[],
  'ageCategories': <dynamic>[],
  'selections': <dynamic>[],
  'declaration': null,
  'formFooter': null,
  'terms': <dynamic>[],
  'termsNotes': <dynamic>[],
  'labelOverrides': <String, dynamic>{},
  'id': id,
  'status': 'draft',
  'layout': null,
  'fittingCategories': null,
  'publishId': null,
  'createdBy': 'test_admin',
  'createdAtUtc': 1767225600000,
  'updatedAtUtc': 1767225600000,
};
