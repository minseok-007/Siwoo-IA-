# Criterion C – Development

## Table of Contents
1. Project Overview  
2. Development Environment and Tooling  
3. Solution Architecture Overview  
4. Authentication and Role Provisioning  
5. Data Modeling and Firestore Integration  
6. Dog Profiling and Preference Capture  
7. Walk Request Lifecycle  
8. Intelligent Matching Algorithms  
9. Real-Time Messaging and Collaboration  
10. Validation and Error Handling  
11. Performance Optimization  
12. Code Quality and Maintainability  
13. Testing and Debugging  
14. Screenshots and Artefacts  
15. Sources and Acknowledgements  
16. Conclusion

---

## 1. Project Overview
PawPal is a Flutter + Firebase platform that connects dog owners with professional walkers. The solution guides users from account creation through role-specific workflows, dog profiling, intelligent matching, walk request management, and in-app chat. Accuracy and timeliness are reinforced through data validation, real-time Firestore streams, and robust error handling.

**Key capabilities.**
- Role-based authentication (dog owner vs dog walker) with Provider-driven routing.
- Weighted and optimized matching algorithms that consider geospatial distance, schedule overlap, experience, rating, and price.
- Walk request lifecycle covering submission, acceptance, status updates, and post-walk coordination.
- Comprehensive dog profiles and owner preferences used to personalise matches.
- Real-time messaging with server-timestamp ordering for every accepted walk.

---

## 2. Development Environment and Tooling
The application is written in Dart using Flutter 3 for cross-platform UI, chosen for its mature widget catalog and hot-reload workflow that accelerates iterative prototyping demanded by Criterion A’s user stories. Firebase provides managed backend services: Firebase Authentication secures sign-in flows, Cloud Firestore offers scalable document storage with real-time listeners, and Firebase Cloud Storage (planned) handles media assets. These tools are adequate because they remove server maintenance overhead, provide built-in security rules, and integrate seamlessly with Flutter via first-party SDKs—crucial for a student project with limited deployment infrastructure.

Supporting packages include `provider` for dependency injection and reactive state propagation, `cloud_firestore` and `firebase_auth` for typed database/auth access, and `google_fonts` for consistent typography. Each package is open-source, well-documented, and aligned with school network policies. Development occurs in Android Studio with Flutter tooling, Git for version control, and the Firebase Emulator Suite for safe local testing, ensuring that experimentation never compromises production data. Firestore security rules restrict each user to their own documents (owners to their dogs/requests, walkers to assigned jobs), providing an adequate security posture without building custom servers. This toolchain delivers the reliability and velocity needed to meet Criterion B success criteria around responsiveness and real-time updates. Deployment-ready builds can be published either to Firebase Hosting (for Flutter Web) or packaged for the iOS/Android app stores using the same CLI, ensuring the infrastructure scales beyond the classroom demo.

## 3. Solution Architecture Overview
The final product is organised into three cooperating layers that mirror the scenario outlined in Criteria A and B:

- **Presentation layer (Flutter widgets).** Screens such as `SignupScreen`, `HomeScreen`, and `ChatScreen` render dynamic UI based on Provider state. Responsive layouts (see `lib/widgets/responsive_layout.dart`) and theming deliver a consistent experience on tablets and phones while showcasing the required user interface techniques.
- **Domain layer (immutable models + providers).** Models (`UserModel`, `DogModel`, `WalkRequestModel`, `MessageModel`) encapsulate business rules, while `AuthProvider` and other ChangeNotifiers expose reactive state. Immutability ensures that widget rebuilds do not mutate shared data, satisfying the need for robust data structures.
- **Service layer (Firebase integration).** Services such as `AuthService`, `DogService`, `WalkRequestService`, and `MessageService` abstract Firestore queries, authentication, and server timestamps. This separation allows algorithmic components (matching, scheduling) to be tested independently from UI code, evidencing deliberate software engineering.

Architecture decisions directly reflect Criterion A requirements: owners must manage dogs, request walks, review matches, and message walkers without friction, while walkers need immediate visibility into assignments. The layered structure supports these flows by maintaining single sources of truth and enabling reuse (for example, the same `WalkRequestModel` feeds matching, notifications, and chat). Extended writing throughout this report documents how each module contributes to the scenario solution.

---

## 4. Authentication and Role Provisioning
The user journey begins with registration. `SignupScreen` collects credentials, personal details, and a mandatory role selection. Choosing the walker role dynamically reveals additional preference controls, enforced through client-side validation before any Firebase calls.

**Code reference – `lib/screens/signup_screen.dart`:**
```dart
final success = await authProvider.signUp(
  email: _emailController.text.trim(),
  password: _passwordController.text,
  fullName: _fullNameController.text.trim(),
  phoneNumber: _phoneController.text.trim(),
  userType: _selectedUserType,
  experienceLevel: _experienceLevel,
  hourlyRate: _hourlyRate,
  maxDistance: _maxDistance,
  preferredDogSizes: _preferredDogSizes,
  availableDays: _availableDays,
  preferredTimeSlots: _preferredTimeSlots,
  preferredTemperaments: _preferredTemperaments,
  preferredEnergyLevels: _preferredEnergyLevels,
  supportedSpecialNeeds: _supportedSpecialNeeds,
);
```

`AuthProvider` wraps Firebase Authentication and immediately hydrates the user document so the UI knows which dashboard to present. During sign-up the service persists the role slug alongside identity data; during sign-in it reloads the same model to restore permissions.

**Code reference – `lib/services/auth_provider.dart`:**
```dart
Future<bool> signIn({required String email, required String password}) async {
  final userCredential = await _authService.signInWithEmailAndPassword(
    email: email,
    password: password,
  );
  _user = userCredential.user;
  await _loadUserData(_user!.uid); // Fetches UserModel with stored userType enum
  return true;
}

UserModel? get userModel => _userModel; // Exposes dogOwner vs dogWalker
```

Once authenticated, `AuthWrapper` and `HomeScreen` (see `lib/screens/home_screen.dart`) branch on `userModel.userType` to reveal owner-specific quick actions (e.g., create walk request) or walker-specific pipelines (e.g., view open assignments). This immediate role recovery eliminates redundant prompts and prevents unauthorized access to the wrong workflow.

---

## 5. Data Modeling and Firestore Integration
Domain models are immutable Dart classes with enum-backed fields, giving compile-time guarantees across the app. Firestore mappings are handled by each model so serialization stays close to business logic.

**Rationale.** Treating models as immutable value objects removes side effects during widget rebuilds and keeps Provider-driven state predictable. Enum-backed fields constrain categories such as roles, dog sizes, or request statuses, so business rules cannot be broken through string typos. By co-locating `toFirestore`/`fromFirestore` methods with each model, schema adjustments happen in a single place, ensuring that matching, scheduling, and messaging features all consume consistent data representations.

**Code reference – `lib/models/message_model.dart`:**
```dart
class MessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String text;
  final DateTime timestamp;

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MessageModel(
      id: doc.id,
      chatId: data['chatId'] ?? '',
      senderId: data['senderId'] ?? '',
      text: data['text'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }
}
```


---

## 6. Dog Profiling and Preference Capture
Owners curate dog profiles through forms backed by `DogService`, ensuring Firestore writes are centralized and reusable. Captured traits directly influence matching and scheduling decisions.

**Rationale.** Detailed dog metadata feeds multiple functional surfaces: temperament and energy levels calibrate the weighted matching score, medical conditions trigger warnings for incompatible walkers, and boolean comfort flags populate the walk detail banner so expectations are clear before acceptance. Centralizing persistence inside `DogService` lets the owner dashboard, walker previews, and analytics reuse the same queries, eliminating discrepancies between screens.

**Code reference – `lib/services/dog_service.dart`:**
```dart
class DogService {
  final CollectionReference _dogsCollection =
      FirebaseFirestore.instance.collection('dogs');

  Future<void> addDog(DogModel dog) async {
    await _dogsCollection.doc(dog.id).set(dog.toFirestore());
  }

  Future<List<DogModel>> getDogsByOwner(String ownerId) async {
    final query = await _dogsCollection.where('ownerId', isEqualTo: ownerId).get();
    return query.docs.map((doc) => DogModel.fromFirestore(doc)).toList();
  }
}
```

When walkers sign up, preference pickers capture acceptable dog sizes, temperaments, energy levels, and special needs. Those lists are stored in the `UserModel` and reused by the matching engine, keeping the platform sensitive to both dog requirements and walker comfort zones.

---

## 7. Walk Request Lifecycle
After onboarding, an owner uses `HomeScreen` to launch `WalkRequestFormScreen`, selecting a dog, timeframe, location, budget, and notes. The form serializes to a `WalkRequestModel` and persists through `WalkRequestService.addWalkRequest`, automatically stamping Firestore creation metadata.

Walkers browse pending requests, inspect details, and accept assignments. The acceptance path enforces authentication, updates Firestore, and returns feedback to both parties.

**Rationale.** Encoding the lifecycle as enum transitions (`pending → accepted → completed/cancelled`) keeps the UI honest: walkers cannot accept an already assigned job, owners retain cancellation control, and completed walks can safely unlock review prompts. Persisting changes through `WalkRequestService` means chat availability, calendar views, and revenue summaries all key off the same authoritative document, even if multiple devices act simultaneously.

**Code reference – `lib/services/walk_request_service.dart`:**
```dart
Future<void> addWalkRequest(WalkRequestModel request) async {
  await walkRequestsCollection.doc(request.id).set(request.toFirestore());
}

Future<void> updateWalkRequest(WalkRequestModel request) async {
  await walkRequestsCollection.doc(request.id).update(request.toFirestore());
}
```

**Code reference – `lib/screens/walk_request_detail_screen.dart`:**
```dart
Future<void> _acceptRequest() async {
  final updated = _request.copyWith(
    status: WalkRequestStatus.accepted,
    walkerId: user.uid,
  );
  await _service.updateWalkRequest(updated);
  setState(() => _request = updated);
}
```

Status transitions (`pending → accepted → completed` or `cancelled`) are encoded in the enum, preventing invalid state changes. The same screen also exposes owner-only cancellations and a quick link into the chat screen once the walk is accepted. All queries and updates run through dedicated services to keep Firestore usage consistent and traceable.

---

## 8. Intelligent Matching Algorithms
Matching combines multiple algorithms to evaluate compatibility and optionally compute global optima when pairing many walkers with many requests. This subsystem showcases algorithmic thinking by decomposing the assignment challenge into measurable factors, weighting them, and applying optimisation routines to produce explainable, high-quality matches.

### 8.1 Haversine Distance Calculation
**Purpose.** Compute the great-circle distance between two latitude/longitude points.  
**Complexity.** O(1) time, O(1) space.

**Rationale.** Accurate distance calculations power every location-sensitive feature: match scoring, eligibility cut-offs, and informative walk summaries. Using the Haversine formula instead of a simple Euclidean approximation keeps results reliable across large metro areas without incurring the cost of external map services.

**Code reference – `lib/services/matching_service.dart`:**
```dart
static double calculateDistance(GeoPoint point1, GeoPoint point2) {
  final double lat1 = point1.latitude * pi / 180;
  final double lat2 = point2.latitude * pi / 180;
  final double deltaLat = (point2.latitude - point1.latitude) * pi / 180;
  final double deltaLon = (point2.longitude - point1.longitude) * pi / 180;

  final double a = sin(deltaLat / 2) * sin(deltaLat / 2) +
      cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2);
  final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

  return _earthRadius * c;
}
```

### 8.2 Weighted Matching Score
**Purpose.** Produce a composite score covering distance, dog attributes, schedule, experience, rating, and price.  
**Complexity.** O(n) per request where *n* is candidate walkers; O(n) space for results.

**Rationale.** The weighted sum translates product priorities into tunable coefficients. Because each factor returns a normalized sub-score, the UI can surface transparent explanations (e.g., “Great match: perfect schedule overlap”) via the `MatchResult.breakdown`, helping owners trust automated recommendations while giving developers a single place to adjust marketplace behaviour.

**Code reference – `lib/services/matching_service.dart`:**
```dart
static const Map<String, double> _matchingWeights = {
  'distance': 0.25,
  'dogSize': 0.20,
  'schedule': 0.20,
  'experience': 0.15,
  'rating': 0.10,
  'price': 0.10,
};

static double _calculateOverallMatchScore(
  UserModel walker,
  WalkRequestModel walkRequest,
  UserModel owner,
  DogModel dog,
) {
  final distance = calculateDistance(walker.location!, owner.location!);
  final distanceScore = calculateDistanceScore(distance, walker.maxDistance);
  final dogSizeScore = calculateDogSizeScore(walker.preferredDogSizes, dog.size);
  final scheduleScore = calculateScheduleScore(/* ... */);
  final experienceScore = calculateExperienceScore(walker.experienceLevel, dog);
  final ratingScore = calculateRatingScore(walker.rating);
  final priceScore = calculatePriceScore(
    walker.hourlyRate,
    walkRequest.budget ?? 50.0,
    0.5,
  );

  double totalScore = 0.0;
  totalScore += distanceScore * _matchingWeights['distance']!;
  totalScore += dogSizeScore * _matchingWeights['dogSize']!;
  totalScore += scheduleScore * _matchingWeights['schedule']!;
  totalScore += experienceScore * _matchingWeights['experience']!;
  totalScore += ratingScore * _matchingWeights['rating']!;
  totalScore += priceScore * _matchingWeights['price']!;

  return totalScore / totalWeight;
}
```

### 8.3 Hungarian Algorithm
**Purpose.** Create an optimal one-to-one assignment between walkers and walk requests.  
**Complexity.** O(n³) time, O(n²) space due to the cost matrix.

**Rationale.** Batch scheduling scenarios—like a surge of evening requests—benefit from globally optimal assignments. The Hungarian algorithm prevents greedy conflicts where one high-quality walker is locked into a mediocre request, keeping overall satisfaction high and documenting the use of advanced algorithms for the IA.

**Code reference – `lib/services/matching_service.dart`:**
```dart
static List<int> _hungarianAlgorithm(List<List<double>> costMatrix) {
  final int n = costMatrix.length;
  final List<int> assignment = List.generate(n, (i) => -1);

  _subtractRowMinima(costMatrix);
  _subtractColMinima(costMatrix);
  // ... row/column cover logic, uncover adjustments.
  return assignment;
}
```

### 8.4 Exponential Distance Decay
**Purpose.** Reward closer matches while avoiding harsh cut-offs.  
**Complexity.** O(1) time, O(1) space.

**Rationale.** Smooth decay curves create nuanced ranking: urban owners see tight differentiation between nearby walkers, while suburban owners still receive viable options slightly outside their ideal radius. This balances fairness with practicality and avoids abrupt drops in score that would otherwise remove usable matches.

**Code reference – `lib/services/matching_service.dart`:**
```dart
static double calculateDistanceScore(double distance, double maxDistance) {
  if (distance <= 0) return 1.0;
  if (distance >= maxDistance) return 0.0;
  return exp(-distance / (maxDistance * 0.3));
}
```

Threshold filtering (score > 0.3) and capped result sets ensure only high-quality matches reach the UI. For each accepted match, `MatchResult` stores a factor breakdown so the UI can explain why a walker was suggested.

---

## 9. Real-Time Messaging and Collaboration
Once a walk is accepted, both parties communicate through a Firestore-backed chat. Each walk owns a chat document with a `messages` subcollection, ensuring minimal read/write contention.

**Code reference – `lib/services/message_service.dart`:**
```dart
class MessageService {
  final CollectionReference chatsCollection =
      FirebaseFirestore.instance.collection('chats');

  Future<void> sendMessage(MessageModel message) async {
    await chatsCollection
        .doc(message.chatId)
        .collection('messages')
        .doc(message.id)
        .set(message.toFirestore());
  }

  Stream<List<MessageModel>> getMessages(String chatId) {
    return chatsCollection
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MessageModel.fromFirestore(doc))
            .toList());
  }
}
```

`ChatListScreen` filters conversations by role, ensuring owners only see their own requests and walkers only see accepted assignments. The chat screen itself uses `StreamBuilder` to render live updates, align bubbles based on sender, and insert date separators for readability.

**Rationale.** Role-aware filtering keeps the inbox focused on actionable conversations and prevents information leakage across accounts. Real-time streams eliminate manual refresh, so the same Firestore update that flips a request to `accepted` also unlocks messaging, enabling immediate coordination about arrival time or dog care notes.

**Code reference – `lib/screens/chat_screen.dart`:**
```dart
StreamBuilder<List<MessageModel>>(
  stream: _service.getMessages(widget.chatId),
  builder: (context, snapshot) {
    final messages = snapshot.data ?? [];
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        final isMe = msg.senderId == widget.userId;
        final showDate = index == 0 ||
            !_isSameDay(messages[index - 1].timestamp, msg.timestamp);
        // ... bubble layout omitted for brevity
      },
    );
  },
)
```

Outbound messages reuse the same service, clear the composer, and animate the scroll once Firestore confirms delivery. Errors surface via localized `SnackBar`s so users know if a message fails to send.

---

## 10. Validation and Error Handling
Client-side validation complements Firestore’s flexible schema. Forms use `GlobalKey<FormState>` with custom validators to prevent malformed entries and to tailor requirements for walker sign-ups.

**Code reference – `lib/utils/validators.dart`:**
```dart
static String? validateEmail(String? value, [BuildContext? context]) {
  if (value == null || value.isEmpty) {
    return 'Email is required';
  }
  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
  if (!emailRegex.hasMatch(value)) {
    return 'Please enter a valid email address';
  }
  return null;
}
```

Services wrap Firestore calls in try/catch blocks, mapping provider errors to user-friendly messages. For example, `WalkRequestService.getRequestsByWalker` throws a descriptive exception on failure, while UI screens present localized `SnackBar`s (see `walk_request_detail_screen.dart` and `chat_screen.dart`). This defensive stance keeps the app stable even when network or permission issues occur.

**Rationale.** Firestore’s schema-less design can silently accept malformed data if not policed. Centralizing validation and converting raw exceptions into localized guidance stops walkers from accepting requests missing a location, alerts owners when authentication expires, and demonstrates intentional error resilience—an IB scoring focus.

---

## 11. Code Quality and Maintainability
Separation of concerns guides the project structure. Services encapsulate Firebase access, models describe domain entities, and widgets consume streams or futures without retaining business logic. This improves readability and supports independent testing of each layer.

**Code reference – `lib/services/auth_service.dart`:**
```dart
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> updateUserData(UserModel user) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.id)
        .update(user.toFirestore());
  }
}
```

`HomeScreen`, `WalkRequestListScreen`, and other widgets listen to `AuthProvider` so they react to role changes without manual refresh. Logging utilities (`DebugLogger`) and error handlers centralize diagnostics, making it easier to trace issues across asynchronous boundaries.

**Rationale.** Keeping Firebase access inside services means new components—like future analytics dashboards or push notification handlers—can plug in without duplicating logic. This modularity also simplifies testing, since mocks can replace services while UI widgets remain untouched, demonstrating disciplined software engineering rather than ad-hoc scripting.

Consistent formatting (`dart format`) and static analysis (`flutter analyze`) are run before releases, and meaningful inline comments are reserved for complex logic such as matching heuristics. These practices keep the codebase maintainable for future contributors and align with Criterion C’s expectation of professional quality.

---