/// Application template payloads for the unit tests (#66, club_server#93).
///
/// [applicationContentJson] is the content an admin sends, in the shape of
/// club_server's own `tests/application_helpers.py::template_body`: English
/// and Marathi, every kind of fact, custom texts, clause references with
/// and without arguments, fact references, a header line of two clauses, a
/// custom term and a note with an attribution. It is fictional and
/// club-neutral.
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
  'subtitle': {'fact': 'camp'},
  'header': [
    {'fact': 'venue'},
    [
      {
        'clause': 'header.training_camp',
        'args': {'dates': 'camp'},
      },
      {
        'clause': 'header.matches',
        'args': {'dates': 'matches'},
      },
    ],
    {'fact': 'phone'},
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
      'clause': 'selection.attend_training_camp',
      'args': {'dates': 'camp'},
    },
  ],
  'declaration': {'clause': 'declaration.trial'},
  'formFooter': {'en': 'Play fair, play hard.', 'mr': 'खिलाडूवृत्तीने खेळा.'},
  'terms': [
    {'clause': 'rule.identity_proof'},
    {
      'clause': 'rule.matches',
      'args': {'dates': 'matches', 'venue': 'venue'},
    },
    {
      'heading': {'en': 'Kit', 'mr': 'साहित्य'},
      'body': {'en': 'Bring your own helmet.', 'mr': 'स्वतःचे हेल्मेट आणा.'},
    },
  ],
  'termsNotes': [
    {'clause': 'note.follow_rules'},
    {
      'text': {'clause': 'note.keys_to_success'},
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
  'createdBy': 'test_admin',
  'createdAtUtc': 1767225600000,
  'updatedAtUtc': 1767225600000,
};
