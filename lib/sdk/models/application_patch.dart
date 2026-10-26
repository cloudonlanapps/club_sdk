import 'package:meta/meta.dart';

import 'application_age_category.dart';
import 'application_content.dart';
import 'application_fact.dart';
import 'application_header_item.dart';
import 'application_term.dart';
import 'application_terms_note.dart';
import 'application_text.dart';

/// A change to a draft application template, for
/// `ApplicationSource.updateApplication` (club_server#93, R3).
///
/// Each field follows the ValueGetter pattern: an omitted (null) getter
/// leaves the stored value as it is, and a getter returning null clears it
/// (a text to none, a list or map to empty, `languages` to English only).
/// A getter returning a value replaces the stored one whole — a list is
/// not merged.
@immutable
class ApplicationPatch {
  const ApplicationPatch({
    this.languages,
    this.facts,
    this.organisation,
    this.title,
    this.subtitle,
    this.header,
    this.ageCategories,
    this.selections,
    this.declaration,
    this.formFooter,
    this.terms,
    this.termsNotes,
    this.labelOverrides,
  });

  /// Replaces every field with [content]'s: the editor's whole state.
  factory ApplicationPatch.replaceAll(ApplicationContent content) =>
      ApplicationPatch(
        languages: () => content.languages,
        facts: () => content.facts,
        organisation: () => content.organisation,
        title: () => content.title,
        subtitle: () => content.subtitle,
        header: () => content.header,
        ageCategories: () => content.ageCategories,
        selections: () => content.selections,
        declaration: () => content.declaration,
        formFooter: () => content.formFooter,
        terms: () => content.terms,
        termsNotes: () => content.termsNotes,
        labelOverrides: () => content.labelOverrides,
      );

  final List<String>? Function()? languages;
  final Map<String, ApplicationFact>? Function()? facts;
  final ApplicationText? Function()? organisation;
  final ApplicationText? Function()? title;
  final ApplicationText? Function()? subtitle;
  final List<ApplicationHeaderItem>? Function()? header;
  final List<ApplicationAgeCategory>? Function()? ageCategories;
  final List<ApplicationText>? Function()? selections;
  final ApplicationText? Function()? declaration;
  final ApplicationText? Function()? formFooter;
  final List<ApplicationTerm>? Function()? terms;
  final List<ApplicationTermsNote>? Function()? termsNotes;
  final Map<String, Map<String, String>>? Function()? labelOverrides;

  /// Whether the patch changes nothing.
  bool get isEmpty => toMap().isEmpty;

  /// The PATCH body: only the fields given, under the server's keys.
  Map<String, dynamic> toMap() {
    final body = <String, dynamic>{};
    void put<T>(String key, T? Function()? getter, Object? Function(T) wire) {
      if (getter == null) return;
      final value = getter();
      body[key] = value == null ? null : wire(value);
    }

    put('languages', languages, (v) => [...v]);
    put(
      'facts',
      facts,
      (v) => {for (final e in v.entries) e.key: e.value.toMap()},
    );
    put('organisation', organisation, (v) => v.toMap());
    put('title', title, (v) => v.toMap());
    put('subtitle', subtitle, (v) => v.toMap());
    put('header', header, (v) => [for (final h in v) h.toWire()]);
    put('ageCategories', ageCategories, (v) => [for (final c in v) c.toMap()]);
    put('selections', selections, (v) => [for (final s in v) s.toMap()]);
    put('declaration', declaration, (v) => v.toMap());
    put('formFooter', formFooter, (v) => v.toMap());
    put('terms', terms, (v) => [for (final t in v) t.toMap()]);
    put('termsNotes', termsNotes, (v) => [for (final n in v) n.toMap()]);
    put(
      'labelOverrides',
      labelOverrides,
      (v) => {
        for (final e in v.entries) e.key: {...e.value},
      },
    );
    return body;
  }

  @override
  String toString() => 'ApplicationPatch(${toMap()})';
}
