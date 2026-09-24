import 'dart:convert';

import 'package:meta/meta.dart';

/// Contact page labels (form, info, map sections).
///
/// Separate from PageData to allow reuse of PageDataScaffold.
@immutable
class ContactPageLabels {
  const ContactPageLabels({
    required this.form,
    required this.info,
    required this.map,
  });

  factory ContactPageLabels.fromMap(Map<String, dynamic> map) {
    return ContactPageLabels(
      form: ContactFormLabels.fromMap(
        map['form'] as Map<String, dynamic>? ?? {},
      ),
      info: ContactInfoLabels.fromMap(
        map['info'] as Map<String, dynamic>? ?? {},
      ),
      map: ContactMapLabels.fromMap(map['map'] as Map<String, dynamic>? ?? {}),
    );
  }

  factory ContactPageLabels.fromJson(String source) =>
      ContactPageLabels.fromMap(json.decode(source) as Map<String, dynamic>);

  final ContactFormLabels form;
  final ContactInfoLabels info;
  final ContactMapLabels map;

  ContactPageLabels copyWith({
    ContactFormLabels? form,
    ContactInfoLabels? info,
    ContactMapLabels? map,
  }) {
    return ContactPageLabels(
      form: form ?? this.form,
      info: info ?? this.info,
      map: map ?? this.map,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'form': form.toMap(),
      'info': info.toMap(),
      'map': map.toMap(),
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() => 'ContactPageLabels(form: $form, info: $info, map: $map)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ContactPageLabels &&
        other.form == form &&
        other.info == info &&
        other.map == map;
  }

  @override
  int get hashCode => form.hashCode ^ info.hashCode ^ map.hashCode;
}

/// Contact form section labels.
@immutable
class ContactFormLabels {
  const ContactFormLabels({
    required this.title,
    required this.description,
    required this.nameLabel,
    required this.namePlaceholder,
    required this.emailLabel,
    required this.emailPlaceholder,
    required this.phoneLabel,
    required this.phonePlaceholder,
    required this.subjectLabel,
    required this.subjectPlaceholder,
    required this.subjectOptions,
    required this.messageLabel,
    required this.messagePlaceholder,
    required this.submitButton,
  });

  factory ContactFormLabels.fromMap(Map<String, dynamic> map) {
    return ContactFormLabels(
      title: map['title'] as String? ?? 'Send us a Message',
      description:
          map['description'] as String? ??
          "Fill out the form below and we'll get back to you within 24 hours.",
      nameLabel: map['nameLabel'] as String? ?? 'Name *',
      namePlaceholder: map['namePlaceholder'] as String? ?? 'Your full name',
      emailLabel: map['emailLabel'] as String? ?? 'Email *',
      emailPlaceholder: map['emailPlaceholder'] as String? ?? 'your@email.com',
      phoneLabel: map['phoneLabel'] as String? ?? 'Phone',
      phonePlaceholder: map['phonePlaceholder'] as String? ?? '(555) 123-4567',
      subjectLabel: map['subjectLabel'] as String? ?? 'Subject *',
      subjectPlaceholder:
          map['subjectPlaceholder'] as String? ?? 'Select a topic',
      subjectOptions: ContactSubjectOptions.fromMap(
        map['subjectOptions'] as Map<String, dynamic>? ?? {},
      ),
      messageLabel: map['messageLabel'] as String? ?? 'Message *',
      messagePlaceholder:
          map['messagePlaceholder'] as String? ?? 'How can we help you?',
      submitButton: map['submitButton'] as String? ?? 'Send Message',
    );
  }

  factory ContactFormLabels.fromJson(String source) =>
      ContactFormLabels.fromMap(json.decode(source) as Map<String, dynamic>);

  final String title;
  final String description;
  final String nameLabel;
  final String namePlaceholder;
  final String emailLabel;
  final String emailPlaceholder;
  final String phoneLabel;
  final String phonePlaceholder;
  final String subjectLabel;
  final String subjectPlaceholder;
  final ContactSubjectOptions subjectOptions;
  final String messageLabel;
  final String messagePlaceholder;
  final String submitButton;

  ContactFormLabels copyWith({
    String? title,
    String? description,
    String? nameLabel,
    String? namePlaceholder,
    String? emailLabel,
    String? emailPlaceholder,
    String? phoneLabel,
    String? phonePlaceholder,
    String? subjectLabel,
    String? subjectPlaceholder,
    ContactSubjectOptions? subjectOptions,
    String? messageLabel,
    String? messagePlaceholder,
    String? submitButton,
  }) {
    return ContactFormLabels(
      title: title ?? this.title,
      description: description ?? this.description,
      nameLabel: nameLabel ?? this.nameLabel,
      namePlaceholder: namePlaceholder ?? this.namePlaceholder,
      emailLabel: emailLabel ?? this.emailLabel,
      emailPlaceholder: emailPlaceholder ?? this.emailPlaceholder,
      phoneLabel: phoneLabel ?? this.phoneLabel,
      phonePlaceholder: phonePlaceholder ?? this.phonePlaceholder,
      subjectLabel: subjectLabel ?? this.subjectLabel,
      subjectPlaceholder: subjectPlaceholder ?? this.subjectPlaceholder,
      subjectOptions: subjectOptions ?? this.subjectOptions,
      messageLabel: messageLabel ?? this.messageLabel,
      messagePlaceholder: messagePlaceholder ?? this.messagePlaceholder,
      submitButton: submitButton ?? this.submitButton,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'nameLabel': nameLabel,
      'namePlaceholder': namePlaceholder,
      'emailLabel': emailLabel,
      'emailPlaceholder': emailPlaceholder,
      'phoneLabel': phoneLabel,
      'phonePlaceholder': phonePlaceholder,
      'subjectLabel': subjectLabel,
      'subjectPlaceholder': subjectPlaceholder,
      'subjectOptions': subjectOptions.toMap(),
      'messageLabel': messageLabel,
      'messagePlaceholder': messagePlaceholder,
      'submitButton': submitButton,
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'ContactFormLabels(title: $title, description: $description)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ContactFormLabels &&
        other.title == title &&
        other.description == description &&
        other.nameLabel == nameLabel &&
        other.namePlaceholder == namePlaceholder &&
        other.emailLabel == emailLabel &&
        other.emailPlaceholder == emailPlaceholder &&
        other.phoneLabel == phoneLabel &&
        other.phonePlaceholder == phonePlaceholder &&
        other.subjectLabel == subjectLabel &&
        other.subjectPlaceholder == subjectPlaceholder &&
        other.subjectOptions == subjectOptions &&
        other.messageLabel == messageLabel &&
        other.messagePlaceholder == messagePlaceholder &&
        other.submitButton == submitButton;
  }

  @override
  int get hashCode =>
      title.hashCode ^
      description.hashCode ^
      nameLabel.hashCode ^
      namePlaceholder.hashCode ^
      emailLabel.hashCode ^
      emailPlaceholder.hashCode ^
      phoneLabel.hashCode ^
      phonePlaceholder.hashCode ^
      subjectLabel.hashCode ^
      subjectPlaceholder.hashCode ^
      subjectOptions.hashCode ^
      messageLabel.hashCode ^
      messagePlaceholder.hashCode ^
      submitButton.hashCode;
}

/// Contact form subject dropdown options.
@immutable
class ContactSubjectOptions {
  const ContactSubjectOptions({
    required this.registration,
    required this.programs,
    required this.facility,
    required this.sponsorship,
    required this.other,
  });

  factory ContactSubjectOptions.fromMap(Map<String, dynamic> map) {
    return ContactSubjectOptions(
      registration: map['registration'] as String? ?? 'Registration Inquiry',
      programs: map['programs'] as String? ?? 'Program Information',
      facility: map['facility'] as String? ?? 'Facility Rental',
      sponsorship: map['sponsorship'] as String? ?? 'Sponsorship',
      other: map['other'] as String? ?? 'Other',
    );
  }

  factory ContactSubjectOptions.fromJson(String source) =>
      ContactSubjectOptions.fromMap(
        json.decode(source) as Map<String, dynamic>,
      );

  final String registration;
  final String programs;
  final String facility;
  final String sponsorship;
  final String other;

  ContactSubjectOptions copyWith({
    String? registration,
    String? programs,
    String? facility,
    String? sponsorship,
    String? other,
  }) {
    return ContactSubjectOptions(
      registration: registration ?? this.registration,
      programs: programs ?? this.programs,
      facility: facility ?? this.facility,
      sponsorship: sponsorship ?? this.sponsorship,
      other: other ?? this.other,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'registration': registration,
      'programs': programs,
      'facility': facility,
      'sponsorship': sponsorship,
      'other': other,
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'ContactSubjectOptions(registration: $registration, '
      'programs: $programs, facility: $facility, '
      'sponsorship: $sponsorship, other: $other)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ContactSubjectOptions &&
        other.registration == registration &&
        other.programs == programs &&
        other.facility == facility &&
        other.sponsorship == sponsorship &&
        other.other == this.other;
  }

  @override
  int get hashCode =>
      registration.hashCode ^
      programs.hashCode ^
      facility.hashCode ^
      sponsorship.hashCode ^
      other.hashCode;
}

/// Contact info section labels.
@immutable
class ContactInfoLabels {
  const ContactInfoLabels({
    required this.title,
    required this.addressLabel,
    required this.phoneLabel,
    required this.emailLabel,
    required this.followUsLabel,
    required this.qrCodeHint,
  });

  factory ContactInfoLabels.fromMap(Map<String, dynamic> map) {
    return ContactInfoLabels(
      title: map['title'] as String? ?? 'Contact Information',
      addressLabel: map['addressLabel'] as String? ?? 'Address',
      phoneLabel: map['phoneLabel'] as String? ?? 'Phone',
      emailLabel: map['emailLabel'] as String? ?? 'Email',
      followUsLabel: map['followUsLabel'] as String? ?? 'Follow Us',
      qrCodeHint:
          map['qrCodeHint'] as String? ?? 'Scan to follow us on Instagram',
    );
  }

  factory ContactInfoLabels.fromJson(String source) =>
      ContactInfoLabels.fromMap(json.decode(source) as Map<String, dynamic>);

  final String title;
  final String addressLabel;
  final String phoneLabel;
  final String emailLabel;
  final String followUsLabel;
  final String qrCodeHint;

  ContactInfoLabels copyWith({
    String? title,
    String? addressLabel,
    String? phoneLabel,
    String? emailLabel,
    String? followUsLabel,
    String? qrCodeHint,
  }) {
    return ContactInfoLabels(
      title: title ?? this.title,
      addressLabel: addressLabel ?? this.addressLabel,
      phoneLabel: phoneLabel ?? this.phoneLabel,
      emailLabel: emailLabel ?? this.emailLabel,
      followUsLabel: followUsLabel ?? this.followUsLabel,
      qrCodeHint: qrCodeHint ?? this.qrCodeHint,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'addressLabel': addressLabel,
      'phoneLabel': phoneLabel,
      'emailLabel': emailLabel,
      'followUsLabel': followUsLabel,
      'qrCodeHint': qrCodeHint,
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'ContactInfoLabels(title: $title, addressLabel: $addressLabel, '
      'phoneLabel: $phoneLabel, emailLabel: $emailLabel, '
      'followUsLabel: $followUsLabel, qrCodeHint: $qrCodeHint)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ContactInfoLabels &&
        other.title == title &&
        other.addressLabel == addressLabel &&
        other.phoneLabel == phoneLabel &&
        other.emailLabel == emailLabel &&
        other.followUsLabel == followUsLabel &&
        other.qrCodeHint == qrCodeHint;
  }

  @override
  int get hashCode =>
      title.hashCode ^
      addressLabel.hashCode ^
      phoneLabel.hashCode ^
      emailLabel.hashCode ^
      followUsLabel.hashCode ^
      qrCodeHint.hashCode;
}

/// Contact map section labels.
@immutable
class ContactMapLabels {
  const ContactMapLabels({
    required this.openInMapsButton,
  });

  factory ContactMapLabels.fromMap(Map<String, dynamic> map) {
    return ContactMapLabels(
      openInMapsButton: map['openInMapsButton'] as String? ?? 'Open in Maps',
    );
  }

  factory ContactMapLabels.fromJson(String source) =>
      ContactMapLabels.fromMap(json.decode(source) as Map<String, dynamic>);

  final String openInMapsButton;

  ContactMapLabels copyWith({
    String? openInMapsButton,
  }) {
    return ContactMapLabels(
      openInMapsButton: openInMapsButton ?? this.openInMapsButton,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'openInMapsButton': openInMapsButton,
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() => 'ContactMapLabels(openInMapsButton: $openInMapsButton)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ContactMapLabels &&
        other.openInMapsButton == openInMapsButton;
  }

  @override
  int get hashCode => openInMapsButton.hashCode;
}
