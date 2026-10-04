/// Evaluation payloads exactly as the server serialises them
/// (club_server#535): every declared field present, unset ones as `null`.
library;

Map<String, dynamic> ratingItemPayload({int id = 11}) => {
  'id': id,
  'isPrivate': false,
  'question': 'Skating',
  'isRequired': true,
  'allowEvidence': true,
  'originItemId': null,
  'type': 'rating',
  'showCommentArea': true,
  'requireCommentFor': [1],
  'rateType': null,
  'rateMin': 1,
  'rateMax': 5,
  'rateValues': null,
};

Map<String, dynamic> levelsItemPayload({int id = 12}) => {
  'id': id,
  'isPrivate': false,
  'question': 'Effort',
  'isRequired': false,
  'allowEvidence': false,
  'originItemId': 3,
  'type': 'rating',
  'showCommentArea': false,
  'requireCommentFor': <int>[],
  'rateType': null,
  'rateMin': null,
  'rateMax': null,
  'rateValues': [
    {'value': 1, 'text': 'Low'},
    {'value': 2, 'text': 'High'},
  ],
};

Map<String, dynamic> yesNoItemPayload({int id = 13}) => {
  'id': id,
  'isPrivate': false,
  'question': 'Wears full kit?',
  'isRequired': true,
  'allowEvidence': false,
  'originItemId': null,
  'type': 'yesNo',
  'showCommentArea': true,
  'requireCommentFor': [false],
  'labelTrue': 'Always',
  'labelFalse': 'Not yet',
};

Map<String, dynamic> singleChoiceItemPayload({int id = 14}) => {
  'id': id,
  'isPrivate': false,
  'question': 'Position',
  'isRequired': false,
  'allowEvidence': false,
  'originItemId': null,
  'type': 'singleChoice',
  'showCommentArea': false,
  'requireCommentFor': <String>[],
  'choices': [
    {'value': 'f', 'text': 'Forward'},
    {'value': 'd', 'text': 'Defence'},
  ],
};

Map<String, dynamic> multipleChoiceItemPayload({int id = 15}) => {
  'id': id,
  'isPrivate': false,
  'question': 'Strengths',
  'isRequired': false,
  'allowEvidence': true,
  'originItemId': null,
  'type': 'multipleChoice',
  'showCommentArea': true,
  'requireCommentFor': ['pass'],
  'choices': [
    {'value': 'shot', 'text': 'Shooting'},
    {'value': 'pass', 'text': 'Passing'},
  ],
};

Map<String, dynamic> numberItemPayload({int id = 16}) => {
  'id': id,
  'isPrivate': true,
  'question': 'Sprint time (s)',
  'isRequired': false,
  'allowEvidence': false,
  'originItemId': null,
  'type': 'number',
  'showCommentArea': true,
  'requireCommentFor': [0, 2.5],
};

Map<String, dynamic> qaItemPayload({int id = 17}) => {
  'id': id,
  'isPrivate': true,
  'question': 'Private notes',
  'isRequired': false,
  'allowEvidence': false,
  'originItemId': null,
  'type': 'qa',
};

Map<String, dynamic> infoItemPayload({int id = 18}) => {
  'id': id,
  'isPrivate': false,
  'type': 'info',
  'markdown': '**Read me**',
};

Map<String, dynamic> templatePayload() => {
  'id': 5,
  'name': 'Term review',
  'createdBy': 'admin1',
  'layout': [
    18,
    {
      'section': 'Skills',
      'items': [11, 13],
    },
  ],
  'items': [infoItemPayload(), ratingItemPayload(), yesNoItemPayload()],
  'inUse': false,
  'createdAtUtc': 1000,
  'updatedAtUtc': 2000,
  'deletedAtUtc': null,
};

Map<String, dynamic> answerPayload() => {
  'itemId': 11,
  'valueNum': 4.0,
  'valueText': null,
  'choices': <String>[],
  'coachNote': 'Good edges',
  'evidence': [
    {'mediaUuid': 'm1', 'metadata': null},
  ],
};

Map<String, dynamic> staffViewPayload() => {
  'id': 21,
  'templateId': 5,
  'createdFor': 'member1',
  'createdBy': 'coach1',
  'owner': null,
  'eventId': 9,
  'periodStartUtc': 3000,
  'periodEndUtc': 4000,
  'status': 'draft',
  'answers': [answerPayload()],
  'createdAtUtc': 1000,
  'updatedAtUtc': 2000,
  'publishedAtUtc': null,
  'deletedAtUtc': null,
};

Map<String, dynamic> memberViewPayload() => {
  'id': 21,
  'createdFor': 'member1',
  'createdBy': 'coach1',
  'owner': 'coach2',
  'eventId': null,
  'periodStartUtc': null,
  'periodEndUtc': null,
  'status': 'published',
  'publishedAtUtc': 5000,
  'template': {
    'id': 5,
    'name': 'Term review',
    'layout': [
      {
        'section': 'Skills',
        'items': [11],
      },
    ],
    'items': [ratingItemPayload()],
  },
  'answers': [answerPayload()],
};
