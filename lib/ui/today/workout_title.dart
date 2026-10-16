/// Format workout names for display without changing stored or editable names.
String workoutTitle(String name) => name.replaceAll(' + ', ' · ');
