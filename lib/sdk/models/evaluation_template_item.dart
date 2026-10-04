import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'evaluation_choice.dart';
import 'evaluation_item_type.dart';
import 'evaluation_rate_level.dart';
import 'evaluation_rate_type.dart';

part 'evaluation_choice_item.dart';
part 'evaluation_info_item.dart';
part 'evaluation_multiple_choice_item.dart';
part 'evaluation_number_item.dart';
part 'evaluation_qa_item.dart';
part 'evaluation_question_item.dart';
part 'evaluation_rating_item.dart';
part 'evaluation_single_choice_item.dart';
part 'evaluation_yes_no_item.dart';

/// Deep equality for the lists items carry.
const evaluationItemListEquality = DeepCollectionEquality();

/// One item of an evaluation template (club_server#535, R12): a question,
/// which takes an answer, or [EvaluationInfoItem] text, which does not.
///
/// A union of one variant per [EvaluationItemType], selected by `type` on
/// the wire; switch over the subclasses to handle each. [id] is assigned
/// by the server and is null on an item being sent for creation; the
/// server ignores it on input. An [isPrivate] item, with its answer, note
/// and evidence, never reaches the member (R39).
@immutable
sealed class EvaluationTemplateItem {
  const EvaluationTemplateItem({this.id, this.isPrivate = false});

  /// Reads the variant `type` names. An unknown type throws
  /// [ArgumentError].
  factory EvaluationTemplateItem.fromMap(Map<String, dynamic> map) {
    return switch (EvaluationItemType.fromWire(map['type'] as String)) {
      EvaluationItemType.rating => EvaluationRatingItem.fromMap(map),
      EvaluationItemType.yesNo => EvaluationYesNoItem.fromMap(map),
      EvaluationItemType.singleChoice => EvaluationSingleChoiceItem.fromMap(
        map,
      ),
      EvaluationItemType.multipleChoice => EvaluationMultipleChoiceItem.fromMap(
        map,
      ),
      EvaluationItemType.number => EvaluationNumberItem.fromMap(map),
      EvaluationItemType.qa => EvaluationQaItem.fromMap(map),
      EvaluationItemType.info => EvaluationInfoItem.fromMap(map),
    };
  }

  factory EvaluationTemplateItem.fromJson(String source) =>
      EvaluationTemplateItem.fromMap(
        json.decode(source) as Map<String, dynamic>,
      );

  /// Server-assigned id; null on input.
  final int? id;

  /// Whether the item stays off the member's view (R39).
  final bool isPrivate;

  /// Which variant this is.
  EvaluationItemType get type;

  /// The wire shape, valid as a request body: the server ignores [id].
  Map<String, dynamic> toMap();

  String toJson() => json.encode(toMap());
}
