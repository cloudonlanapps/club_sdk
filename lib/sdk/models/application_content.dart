import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'application_age_category.dart';
import 'application_fact.dart';
import 'application_header_item.dart';
import 'application_term.dart';
import 'application_terms_note.dart';
import 'application_text.dart';

/// Everything an admin writes on an application template (club_server#93,
/// R6–R9): what `POST /applications` takes and every template carries.
///
/// The defaults are the server's: English only, no facts, no texts, empty
/// lists. [toMap] writes the server's camelCase keys and the nested values
/// in the shapes they were read in, so a template's content can be sent
/// back as it came — to create another, or as an editor's whole state.
@immutable
class ApplicationContent {
  const ApplicationContent({
    this.languages = const ['en'],
    this.facts = const {},
    this.organisation,
    this.title,
    this.subtitle,
    this.header = const [],
    this.ageCategories = const [],
    this.selections = const [],
    this.declaration,
    this.formFooter,
    this.terms = const [],
    this.termsNotes = const [],
    this.labelOverrides = const {},
  });

  /// Reads the content keys of [map]; other keys (a template's `id`,
  /// `status`, …) are ignored, and a missing key takes its default.
  factory ApplicationContent.fromMap(Map<String, dynamic> map) {
    List<T> list<T>(String key, T Function(Object) read) =>
        ((map[key] as List?) ?? const [])
            .map((e) => read(e as Object))
            .toList(growable: false);
    Map<String, dynamic> obj(Object e) => e as Map<String, dynamic>;
    return ApplicationContent(
      languages: List<String>.unmodifiable(
        (map['languages'] as List?) ?? const ['en'],
      ),
      facts: {
        for (final e in ((map['facts'] as Map?) ?? const {}).entries)
          e.key as String: ApplicationFact.fromMap(obj(e.value as Object)),
      },
      organisation: ApplicationText.fromWire(map['organisation']),
      title: ApplicationText.fromWire(map['title']),
      subtitle: ApplicationText.fromWire(map['subtitle']),
      header: list('header', ApplicationHeaderItem.fromWire),
      ageCategories: list(
        'ageCategories',
        (e) => ApplicationAgeCategory.fromMap(obj(e)),
      ),
      selections: list('selections', (e) => ApplicationText.fromMap(obj(e))),
      declaration: ApplicationText.fromWire(map['declaration']),
      formFooter: ApplicationText.fromWire(map['formFooter']),
      terms: list('terms', (e) => ApplicationTerm.fromMap(obj(e))),
      termsNotes: list(
        'termsNotes',
        (e) => ApplicationTermsNote.fromMap(obj(e)),
      ),
      labelOverrides: {
        for (final e in ((map['labelOverrides'] as Map?) ?? const {}).entries)
          e.key as String: ApplicationText.stringMap(e.value as Map),
      },
    );
  }

  /// The print languages: `["en"]` or `["en", <one other>]`.
  final List<String> languages;

  /// The template's facts by name.
  final Map<String, ApplicationFact> facts;

  /// The top line: the organisation the form is addressed to.
  final ApplicationText? organisation;

  /// The form's title.
  final ApplicationText? title;

  /// An optional line under the title.
  final ApplicationText? subtitle;

  /// The header strip's items: venue, dates, phone, ….
  final List<ApplicationHeaderItem> header;

  /// The age groups, every one printed, the member's ticked.
  final List<ApplicationAgeCategory> ageCategories;

  /// "Additional selections", each printed with an empty checkbox.
  final List<ApplicationText> selections;

  /// The text above the signatures.
  final ApplicationText? declaration;

  /// The closing line under the signatures.
  final ApplicationText? formFooter;

  /// The rules on page 2.
  final List<ApplicationTerm> terms;

  /// The notes boxed under the rules.
  final List<ApplicationTermsNote> termsNotes;

  /// Standard label id → its text per language, replacing the catalogue's.
  final Map<String, Map<String, String>> labelOverrides;

  ApplicationContent copyWith({
    List<String>? languages,
    Map<String, ApplicationFact>? facts,
    ApplicationText? Function()? organisation,
    ApplicationText? Function()? title,
    ApplicationText? Function()? subtitle,
    List<ApplicationHeaderItem>? header,
    List<ApplicationAgeCategory>? ageCategories,
    List<ApplicationText>? selections,
    ApplicationText? Function()? declaration,
    ApplicationText? Function()? formFooter,
    List<ApplicationTerm>? terms,
    List<ApplicationTermsNote>? termsNotes,
    Map<String, Map<String, String>>? labelOverrides,
  }) {
    return ApplicationContent(
      languages: languages ?? this.languages,
      facts: facts ?? this.facts,
      organisation: organisation != null ? organisation() : this.organisation,
      title: title != null ? title() : this.title,
      subtitle: subtitle != null ? subtitle() : this.subtitle,
      header: header ?? this.header,
      ageCategories: ageCategories ?? this.ageCategories,
      selections: selections ?? this.selections,
      declaration: declaration != null ? declaration() : this.declaration,
      formFooter: formFooter != null ? formFooter() : this.formFooter,
      terms: terms ?? this.terms,
      termsNotes: termsNotes ?? this.termsNotes,
      labelOverrides: labelOverrides ?? this.labelOverrides,
    );
  }

  Map<String, dynamic> toMap() => {
    'languages': [...languages],
    'facts': {for (final e in facts.entries) e.key: e.value.toMap()},
    'organisation': organisation?.toMap(),
    'title': title?.toMap(),
    'subtitle': subtitle?.toMap(),
    'header': [for (final h in header) h.toWire()],
    'ageCategories': [for (final c in ageCategories) c.toMap()],
    'selections': [for (final s in selections) s.toMap()],
    'declaration': declaration?.toMap(),
    'formFooter': formFooter?.toMap(),
    'terms': [for (final t in terms) t.toMap()],
    'termsNotes': [for (final n in termsNotes) n.toMap()],
    'labelOverrides': {
      for (final e in labelOverrides.entries) e.key: {...e.value},
    },
  };

  @override
  String toString() => 'ApplicationContent(${toMap()})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApplicationContent &&
          const DeepCollectionEquality().equals(other.toMap(), toMap());

  @override
  int get hashCode => const DeepCollectionEquality().hash(toMap());
}
