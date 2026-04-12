class AgeValidator {
  /// Checks if the given date of birth is strictly 18 years or older.
  static bool isAdult(DateTime dob) {
    final today = DateTime.now();
    int age = today.year - dob.year;
    
    if (today.month < dob.month || (today.month == dob.month && today.day < dob.day)) {
      age--;
    }
    
    return age >= 18;
  }
}
