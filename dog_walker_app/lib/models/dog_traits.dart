/// Shared dog attribute enums used across user and dog models.
/// Extracted into a dedicated file to avoid circular imports between models.

/// Enumeration representing a dog's temperament.
/// Using enums reduces string typos and keeps comparisons/storage type-safe.
enum DogTemperament { calm, friendly, energetic, shy, aggressive, reactive }

/// Energy level (used for walk/activity matching).
enum EnergyLevel { low, medium, high, veryHigh }

/// Represents special care needs; allow multiple selections via a list.
enum SpecialNeeds { none, medication, elderly, puppy, training, socializing }
