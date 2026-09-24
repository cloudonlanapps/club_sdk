# Rule: Dart Data Class Generation

Follow this standard for all Dart data class generation and updates in this project. This ensures consistency with the `ricardo-emerson.dart-data-class-tools` extension.

## Class Requirements

1.  **Immutability**: 
    - Use the `@immutable` annotation from `package:meta/meta.dart`.
    - All fields must be `final`.

2.  **Constructor**:
    - Use `const` where possible.
    - Non-nullable fields: `required this.field`.
    - Nullable fields: `this.field`.

3.  **Correct `copyWith` Implementation**:
    - **CRITICAL**: To allow setting nullable fields to `null`, use the **ValueGetter** pattern.
    - Required pattern: `T? Function()? name` for nullable types.
    - Example:
      ```dart
      User copyWith({
        String? id,               // Non-nullable in class, standard ?? used
        String? Function()? bio,  // Nullable in class, ValueGetter used
      }) {
        return User(
          id: id ?? this.id,
          bio: bio != null ? bio() : this.bio,
        );
      }
      ```

4.  **Serialization**:
    - `Map<String, dynamic> toMap()`: Standard map conversion.
    - `factory Class.fromMap(Map<String, dynamic> map)`: Map to object conversion.
    - Add null-safety defaults in `fromMap` (e.g., `?? ''`, `List.from(map['list'] ?? [])`).
    - `toJson()`: `json.encode(toMap())`.
    - `fromJson()`: `Class.fromMap(json.decode(source))`.

5.  **Boilerplate Methods**:
    - `toString()`: Descriptive representation: `Class(field: $field, ...)`.
    - `operator ==`: Deep equality check for all fields.
    - `hashCode`: Combined hash of all fields.

## Reference Implementation
See `sdk/lib/src/models/example_model.dart` or `sdk/lib/src/models/user.dart`.
