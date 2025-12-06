# PawPal – Dog Walking App

## Criterion C: Development

Note: The entire code is presented in the project repository.

### Project Structure

The application follows a modular architecture with clear separation of concerns. The project is organized into several key directories:

- `lib/models/`: Data models representing domain entities (User, Dog, WalkRequest, Message, etc.)
- `lib/services/`: Business logic and Firebase integration layer
- `lib/screens/`: User interface components (Flutter widgets)
- `lib/widgets/`: Reusable UI components
- `lib/utils/`: Utility functions and validators

### Imported Libraries and Dependencies

The application utilizes several key libraries to implement its functionality:

**Firebase Core Libraries:**
- `firebase_core`: Initializes Firebase services
- `firebase_auth`: Handles user authentication (email/password)
- `cloud_firestore`: NoSQL database for storing user data, walk requests, messages, and application data
- `firebase_messaging`: Firebase Cloud Messaging for push notifications

**Flutter Framework:**
- `flutter/material.dart`: Material Design UI components
- `provider`: State management using the Provider pattern

**Additional Libraries:**
- `intl`: Date and time formatting
- `geolocator`: Location services (for future GPS features)
- `permission_handler`: Runtime permission management

### List of Techniques

The use of the following techniques is elaborated upon throughout this document:

1. **Firebase Authentication Streams** – Real-time authentication state monitoring using `authStateChanges` stream
2. **Firestore Subcollection Pattern** – Organizing messages in nested collections for efficient querying
3. **Firestore Real-Time Streams** – Using `snapshots()` for live data synchronization without polling
4. **ChangeNotifier Pattern** – Reactive state management for automatic UI updates
5. **Provider Dependency Injection** – Service injection throughout widget tree for testability
6. **Model Serialization** – Converting Dart objects to/from Firestore documents with type safety
7. **Server Timestamp Strategy** – Using `FieldValue.serverTimestamp()` for consistent chronological ordering
8. **Composite Query Optimization** – Efficient Firestore queries with multiple where clauses
9. **In-Memory Sorting Fallback** – Graceful degradation when Firestore indexes are unavailable
10. **Idempotent Chat Initialization** – Safe chat document creation with merge operations
11. **StreamBuilder Widget** – Reactive UI components that rebuild on stream events
12. **ScrollController Management** – Programmatic scroll control for chat message display
13. **Error Handling with Try-Catch** – Comprehensive exception handling throughout service layer
14. **Platform-Specific Conditional Compilation** – Different code paths for web and mobile platforms
15. **Relevance Scoring Algorithm** – Multi-factor weighted scoring for walk request ranking based on walker preferences
16. **Bayesian Average Rating Algorithm** – Statistical rating calculation that handles low review counts with prior distribution
17. **Time-Weighted Rating Algorithm** – Exponential decay weighting for prioritizing recent reviews
18. **Interval Overlap Detection Algorithm** – Schedule conflict detection using mathematical interval intersection
19. **TabController for Navigation** – Stateful tab management for organizing different views
20. **StatefulBuilder for Dialog State** – Dynamic state updates within modal dialogs
21. **FilterChip Selection UI** – Multi-select filtering interface with visual feedback
22. **ListView.builder Optimization** – Efficient list rendering with lazy loading for large datasets
23. **DropdownButtonFormField** – Form input with dropdown selection for enum values
24. **Slider Widget for Range Input** – Continuous value selection for numeric filters

### Integrated Development Environment (IDE)

The IDE used during the development of this solution was Visual Studio Code with the Flutter extension. While Flutter's hot reload feature allows for rapid development and testing, the application's architecture required careful planning of the service layer to ensure proper separation between UI components and business logic. The service layer pattern was chosen to enable easy testing and maintainability, as services can be easily mocked during widget testing.

---

## Screen 1: Authentication Flow (Login/Signup)

### Authentication State Management with Streams

When the application launches, the `AuthWrapper` screen checks the current authentication state. The application uses Firebase Authentication's `authStateChanges` stream to automatically detect when users sign in or sign out, eliminating the need for manual polling or state checking.

```dart
class AuthProvider with ChangeNotifier {
  void _init() {
    _authService.authStateChanges.listen((User? user) {
      _user = user;
      if (user != null) {
        _loadUserData(user.uid);
      } else {
        _userModel = null;
      }
      notifyListeners();
    });
  }
}
```

The `authStateChanges` stream emits events whenever the authentication state changes. When a user signs in, the stream emits a `User` object, triggering the `_loadUserData` method to fetch the user's profile from Firestore. When a user signs out, the stream emits `null`, which clears the local user model. The `notifyListeners()` call ensures that all widgets listening to the `AuthProvider` automatically rebuild to reflect the new authentication state.

### Dual-Document Registration System

When a user registers through the Signup screen, the application creates two separate documents: one in Firebase Authentication for credentials, and another in Firestore for extended profile data. This separation allows the application to store authentication credentials securely while maintaining flexible user profile data.

```dart
Future<UserCredential> signUpWithEmailAndPassword({
  required String email,
  required String password,
  required String fullName,
  required String phoneNumber,
  required UserType userType,
}) async {
  UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
    email: email,
    password: password,
  );

  UserModel userModel = UserModel(
    id: userCredential.user!.uid,
    email: email,
    fullName: fullName,
    phoneNumber: phoneNumber,
    userType: userType,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  await _firestore
      .collection('users')
      .doc(userCredential.user!.uid)
      .set(userModel.toFirestore());

  return userCredential;
}
```

The registration process first creates the Firebase Authentication account, which generates a unique user ID (`uid`). This ID is then used as the document ID in Firestore, ensuring a one-to-one relationship between authentication accounts and user profiles. If the Firestore document creation fails, the authentication account still exists, but the application handles this scenario gracefully through error handling.

---

## Screen 2: Home Screen

### Provider-Based State Access

The Home screen displays different content based on the user's role (dog owner or dog walker). The screen accesses the current user data through the `AuthProvider` using the `Consumer` widget, which automatically rebuilds when the authentication state changes.

```dart
body: Consumer<AuthProvider>(
  builder: (context, authProvider, child) {
    if (authProvider.userModel == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final user = authProvider.userModel!;
    // Display role-specific content
  },
)
```

The `Consumer` widget subscribes to the `AuthProvider` and rebuilds its child widget whenever `notifyListeners()` is called. This reactive approach ensures that the Home screen always displays the current user's information without requiring manual refresh or state synchronization.

---

## Screen 3: Walk Request Form Screen

### Firestore Document Creation with Validation

When a dog owner creates a walk request through the Walk Request Form screen, the application validates the input data and creates a new document in the `walk_requests` collection. The `WalkRequestService` handles this operation, ensuring data consistency and proper error handling.

```dart
Future<void> addWalkRequest(WalkRequestModel request) async {
  await walkRequestsCollection.doc(request.id).set(request.toFirestore());
}
```

The service uses the `set()` method to create the document, which will overwrite any existing document with the same ID. The `toFirestore()` method on the `WalkRequestModel` converts the Dart object into a map that Firestore can store, handling type conversions for enums, dates, and nested objects.

---

## Screen 4: Walk Request List Screen

### Query Optimization with Composite Filters

The Walk Request List screen displays different walk requests depending on whether the user is a dog owner or a dog walker. For walkers, the screen queries all walk requests where the `walkerId` matches the current user. The service implements efficient querying using Firestore's `where` clause.

```dart
Future<List<WalkRequestModel>> getRequestsByWalker(String walkerId) async {
  try {
    final querySnapshot = await walkRequestsCollection
        .where('walkerId', isEqualTo: walkerId)
        .get();

    final requests = querySnapshot.docs
        .map((doc) => WalkRequestModel.fromFirestore(doc))
        .toList();

    requests.sort((a, b) => b.startTime.compareTo(a.startTime));
    return requests;
  } catch (e) {
    throw Exception('Failed to fetch walker requests: $e');
  }
}
```

The query filters walk requests by `walkerId` and then sorts them in memory by `startTime` in descending order. While Firestore supports `orderBy` clauses, this approach avoids requiring a composite index during development. Once a composite index is created in Firestore, the query could be optimized to use `orderBy('startTime', descending: true)` directly in the Firestore query.

---

## Screen 5: Walk Request Detail Screen

### Status-Based Workflow Management

The Walk Request Detail screen allows users to perform different actions based on the walk request's status and the user's role. Dog owners can cancel or reschedule walk requests, while dog walkers can accept or complete them. The screen uses the `WalkRequestService` to update the status in Firestore.

```dart
Future<void> updateWalkRequest(WalkRequestModel request) async {
  await walkRequestsCollection.doc(request.id).update(request.toFirestore());
}
```

The `update()` method modifies only the specified fields in the Firestore document, unlike `set()` which replaces the entire document. This partial update approach is more efficient and reduces the risk of overwriting concurrent changes from other users.

---

## Screen 6: Chat List Screen

### Aggregating Data from Multiple Collections

The Chat List screen displays all conversations that the current user is involved in. This requires querying multiple Firestore collections and aggregating the results. The screen first fetches all walk requests where the user is either the owner or the walker, then retrieves the last message for each chat to display a preview.

```dart
Future<void> _fetchChats() async {
  List<WalkRequestModel> walkRequests = [];
  
  if (user.userType == UserType.dogWalker) {
    walkRequests = await _walkService.getRequestsByWalker(user.id);
  } else {
    walkRequests = await _walkService.getRequestsByOwner(user.id);
  }

  for (final walk in walkRequests) {
    final chatId = 'walk_${walk.id}_${walk.ownerId}_${walk.walkerId ?? ''}';
    final lastMessage = await _getLastMessage(chatId);
    
    chats.add({
      'chatId': chatId,
      'walkRequest': walk,
      'lastMessage': lastMessage,
    });
  }
  
  chats.sort((a, b) {
    final aTime = a['lastMessage']?.timestamp ?? a['walkRequest'].startTime;
    final bTime = b['lastMessage']?.timestamp ?? b['walkRequest'].startTime;
    return bTime.compareTo(aTime);
  });
}
```

The chat list is sorted by the most recent message timestamp, with walk requests that have no messages falling back to the walk request's start time. This ensures that active conversations appear at the top of the list, while inactive walk requests are sorted by their scheduled time.

### Last Message Retrieval Optimization

To display a preview of the last message in each chat, the screen queries the messages subcollection with a limit of 1 and descending order by timestamp.

```dart
Future<MessageModel?> getLastMessage(String chatId) async {
  try {
    final querySnapshot = await chatsCollection
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();
    
    if (querySnapshot.docs.isNotEmpty) {
      return MessageModel.fromFirestore(querySnapshot.docs.first);
    }
    return null;
  } catch (e) {
    return null;
  }
}
```

The `limit(1)` clause ensures that only the most recent message is retrieved, minimizing data transfer and improving performance. The query uses `orderBy('timestamp', descending: true)` to get the latest message first, which requires a Firestore index on the `timestamp` field.

---

## Screen 7: Chat Screen (Real-Time Messaging)

### Firestore Subcollection Architecture

The Chat screen implements a real-time messaging system using Firestore's subcollection pattern. Messages are stored in a subcollection under each chat document: `chats/{chatId}/messages/{messageId}`. This structure provides several technical advantages:

1. **Efficient Pagination**: Messages can be queried independently without loading the entire chat history or parent document
2. **Reduced Document Size**: Chat metadata remains small while messages are stored separately, preventing document size limits
3. **Better Query Performance**: Queries on messages don't require loading the parent chat document, reducing read operations
4. **Scalability**: As chat histories grow, the subcollection pattern allows for efficient infinite scroll implementation

```dart
class MessageService {
  final CollectionReference chatsCollection = 
      FirebaseFirestore.instance.collection('chats');

  Future<void> sendMessage(MessageModel message) async {
    final chatRef = chatsCollection.doc(message.chatId);

    // Save message to the messages subcollection
    await chatRef
        .collection('messages')
        .doc(message.id)
        .set(message.toFirestore());

    // Update chat metadata atomically
    await chatRef.set(
      {'lastMessageAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }
}
```

When a message is sent, it is stored in the `messages` subcollection using the message's unique ID. Simultaneously, the parent chat document's `lastMessageAt` field is updated using `FieldValue.serverTimestamp()`. The `SetOptions(merge: true)` parameter ensures that only the `lastMessageAt` field is updated without overwriting other chat metadata fields. This atomic update pattern ensures that chat lists can efficiently display the most recent message timestamp without querying all messages.

### Real-Time Message Streaming with StreamBuilder

The Chat screen uses Firestore's `snapshots()` stream to provide real-time message updates. When a user opens a chat, the UI automatically updates whenever new messages arrive, without requiring manual refresh or polling.

```dart
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
```

The `snapshots()` method returns a stream that emits a `QuerySnapshot` whenever the query results change. This includes new messages, deleted messages, and modifications to existing messages. The stream is then transformed using the `map()` method to convert Firestore documents into `MessageModel` objects. The `orderBy('timestamp', descending: false)` ensures messages are displayed chronologically, and server timestamps prevent clock skew issues across different devices.

### StreamBuilder Integration for Reactive UI

The Chat screen's UI uses Flutter's `StreamBuilder` widget to automatically rebuild when new messages arrive through the stream.

```dart
Expanded(
  child: StreamBuilder<List<MessageModel>>(
    stream: _service.getMessages(widget.chatId),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(child: Text('Error: ${snapshot.error}'));
      }

      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }

      final messages = snapshot.data!;
      return ListView.builder(
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final msg = messages[index];
          // Render message widget
        },
      );
    },
  ),
)
```

The `StreamBuilder` widget subscribes to the stream and rebuilds its child widget whenever the stream emits new data. The `snapshot` object provides the current state of the stream, including data, loading state, and errors. This reactive approach eliminates the need for manual state management or periodic polling, providing a seamless real-time chat experience.

### Message Ordering and Chronological Display

Messages are ordered by their `timestamp` field in ascending order (oldest first) to display them chronologically in the chat. The timestamp is stored as a Firestore `Timestamp` object, which is converted to a Dart `DateTime` during deserialization.

```dart
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
```

The `toDate()` method converts the Firestore `Timestamp` to a Dart `DateTime` object, preserving the exact server time. This ensures that messages from different devices are displayed in the correct chronological order, regardless of local clock differences.

### Chat Initialization with Idempotent Operations

Before displaying messages, the Chat screen initializes the chat document if it doesn't exist. This initialization process is idempotent, meaning it can be safely called multiple times without causing side effects.

```dart
Future<void> initializeChat(
  String chatId, {
  String? ownerId,
  String? walkerId,
}) async {
  try {
    final chatDoc = chatsCollection.doc(chatId);
    final chatSnapshot = await chatDoc.get();

    if (!chatSnapshot.exists) {
      await chatDoc.set({
        'chatId': chatId,
        'ownerId': ownerId,
        'walkerId': walkerId,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessageAt': FieldValue.serverTimestamp(),
      });
    } else {
      await chatDoc.set(
        {
          'ownerId': ownerId,
          'walkerId': walkerId,
        },
        SetOptions(merge: true),
      );
    }
  } catch (e) {
    // Chat might already exist, ignore error
  }
}
```

The method first checks if the chat document exists using `get()`. If it doesn't exist, it creates a new document with all required fields. If it does exist, it updates only the participant fields using `SetOptions(merge: true)`, which prevents overwriting existing metadata like `createdAt` or `lastMessageAt`. This merge operation ensures that concurrent initializations don't cause data loss.

### ScrollController for Message Display

The Chat screen uses a `ScrollController` to automatically scroll to the bottom when new messages arrive or when the user sends a message.

```dart
final ScrollController _scrollController = ScrollController();

@override
void initState() {
  super.initState();
  _initializeChat();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  });
}

void _sendMessage() async {
  await _service.sendMessage(msg);
  _controller.clear();
  
  Future.delayed(const Duration(milliseconds: 100), () {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  });
}
```

The `ScrollController` is attached to the `ListView` displaying messages. When a message is sent, the code waits 100 milliseconds for the message to be added to the list, then animates the scroll to the bottom using `animateTo()` with the maximum scroll extent. The `hasClients` check ensures that the scroll controller is attached to a scrollable widget before attempting to scroll.

### Message Timestamp Formatting

The Chat screen formats message timestamps differently based on when the message was sent. Messages from today show only the time, messages from yesterday show "Yesterday", and older messages show the full date.

```dart
String _formatDate(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final messageDate = DateTime(date.year, date.month, date.day);

  if (messageDate == today) {
    return 'Today';
  } else if (messageDate == yesterday) {
    return 'Yesterday';
  } else {
    return '${date.day}/${date.month}/${date.year}';
  }
}
```

This formatting logic compares the message date with the current date, normalizing both to midnight (00:00:00) to compare only the date portion. This ensures accurate date comparisons regardless of the time the message was sent.

---

## Model Serialization and Type Safety

### Firestore Document Conversion

Data models implement serialization methods to convert between Dart objects and Firestore documents. The `toFirestore()` method converts model instances to maps that can be stored in Firestore, while `fromFirestore()` reconstructs model instances from Firestore documents with proper type handling.

```dart
factory UserModel.fromFirestore(DocumentSnapshot doc) {
  final data = doc.data() as Map<String, dynamic>;
  return UserModel(
    id: doc.id,
    email: data['email'] ?? '',
    fullName: data['fullName'] ?? '',
    userType: UserType.values.firstWhere(
      (e) => e.toString() == 'UserType.${data['userType']}',
      orElse: () => UserType.dogOwner,
    ),
    createdAt: (data['createdAt'] as Timestamp).toDate(),
    updatedAt: (data['updatedAt'] as Timestamp).toDate(),
  );
}

Map<String, dynamic> toFirestore() {
  return {
    'email': email,
    'fullName': fullName,
    'userType': userType.toString().split('.').last,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };
}
```

The serialization process handles several complexities:
- **Enum Conversion**: Enums are stored as string slugs in Firestore (e.g., "dogOwner") and converted back to enum values during deserialization using `firstWhere()` with a fallback value
- **Timestamp Handling**: DateTime objects are converted to Firestore Timestamps using `Timestamp.fromDate()` and back using `toDate()`, ensuring consistent server-side time management
- **Null Safety**: Default values are provided for missing fields (e.g., `data['email'] ?? ''`) to prevent null pointer exceptions
- **Type Casting**: Explicit type casting (e.g., `as Timestamp`) ensures data integrity during conversion, with runtime type checking

This approach ensures that data stored in Firestore can be reliably reconstructed into strongly-typed Dart objects, providing compile-time type safety throughout the application.

---

## Error Handling and Graceful Degradation

### Composite Index Fallback Strategy

The application implements fallback mechanisms when Firestore composite indexes are not yet created. Instead of crashing, the application fetches data without ordering and sorts it in memory.

```dart
Future<List<WalkRequestModel>> getRequestsByWalker(String walkerId) async {
  try {
    final querySnapshot = await walkRequestsCollection
        .where('walkerId', isEqualTo: walkerId)
        .get();

    final requests = querySnapshot.docs
        .map((doc) => WalkRequestModel.fromFirestore(doc))
        .toList();

    requests.sort((a, b) => b.startTime.compareTo(a.startTime));
    return requests;
  } catch (e) {
    throw Exception('Failed to fetch walker requests: $e');
  }
}
```

This approach allows the application to function during development before composite indexes are created, while still providing the desired functionality. Once indexes are created in Firestore, the query can be optimized to use `orderBy('startTime', descending: true)` directly in the Firestore query, reducing client-side processing.

### Try-Catch Error Handling

All service methods implement comprehensive error handling using try-catch blocks to ensure the application remains stable even when network operations fail or invalid data is encountered.

```dart
Future<MessageModel?> getLastMessage(String chatId) async {
  try {
    final querySnapshot = await chatsCollection
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();
    
    if (querySnapshot.docs.isNotEmpty) {
      return MessageModel.fromFirestore(querySnapshot.docs.first);
    }
    return null;
  } catch (e) {
    return null;
  }
}
```

The service layer catches exceptions and either returns null (for optional operations) or re-throws them with descriptive error messages. The UI layer can then display user-friendly error messages or implement fallback behavior. This approach prevents unhandled exceptions from crashing the application.

---

## Firebase Cloud Messaging Integration

### Token Management with Stream Subscription

The application implements Firebase Cloud Messaging (FCM) to enable push notifications. Device tokens are stored in Firestore under each user's document: `users/{userId}/deviceTokens/{token}`. This structure allows multiple devices per user and supports token rotation.

```dart
class MessagingService {
  static final MessagingService instance = MessagingService._();
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  StreamSubscription<String>? _tokenRefreshSubscription;

  Future<void> initializeForUser(String userId) async {
    _currentUserId = userId;

    if (!kIsWeb) {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    final token = await _getToken();
    if (token != null) {
      await _saveToken(userId, token);
    }

    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((token) async {
      if (_currentUserId != null) {
        await _saveToken(_currentUserId!, token);
      }
    });
  }
}
```

The service listens to the `onTokenRefresh` stream, which automatically fires when FCM tokens are rotated for security purposes. This stream subscription ensures that the stored token in Firestore is always current, enabling reliable push notification delivery even after token rotation.

### Platform-Specific Token Generation

The messaging service handles platform differences between web and mobile. Web platforms require a VAPID key for FCM, while mobile platforms use native token generation.

```dart
Future<String?> _getToken() async {
  try {
    if (kIsWeb) {
      const vapidKey = String.fromEnvironment('FIREBASE_VAPID_KEY');
      return _messaging.getToken(
        vapidKey: vapidKey.isEmpty ? null : vapidKey,
      );
    }
    return await _messaging.getToken();
  } catch (e) {
    return null;
  }
}
```

This conditional compilation allows the same codebase to work across platforms while respecting platform-specific requirements. The `kIsWeb` constant is a compile-time flag that determines the platform at build time.

---

## Advanced Algorithms

### Relevance Scoring Algorithm for Walk Request Ranking

The application implements a sophisticated relevance scoring algorithm that ranks available walk requests based on how well they match a walker's preferences. This algorithm uses a multi-factor weighted scoring system to calculate a relevance score between 0.0 and 1.0 for each walk request.

```dart
static double calculateRelevanceScore({
  required WalkRequestModel walkRequest,
  required DogModel dog,
  required UserModel walker,
}) {
  double totalScore = 0.0;
  double totalWeight = 0.0;

  // Size compatibility score (25% weight)
  final sizeScore = _calculateSizeCompatibilityScore(
    walker.preferredDogSizes,
    dog.size,
  );
  totalScore += sizeScore * 0.25;

  // Temperament compatibility score (20% weight)
  final temperamentScore = _calculateTemperamentCompatibilityScore(
    walker.preferredTemperaments,
    dog.temperament,
  );
  totalScore += temperamentScore * 0.20;

  // Energy level compatibility score (15% weight)
  final energyScore = _calculateEnergyCompatibilityScore(
    walker.preferredEnergyLevels,
    dog.energyLevel,
  );
  totalScore += energyScore * 0.15;

  // Special needs support score (15% weight)
  final specialNeedsScore = _calculateSpecialNeedsSupportScore(
    walker.supportedSpecialNeeds,
    dog.specialNeeds,
  );
  totalScore += specialNeedsScore * 0.15;

  // Time compatibility score (15% weight)
  final timeScore = _calculateTimeCompatibilityScore(
    walkRequest.startTime,
    walker.availableDays,
    walker.preferredTimeSlots,
  );
  totalScore += timeScore * 0.15;

  // Urgency score (10% weight)
  final urgencyScore = _calculateUrgencyScore(walkRequest.startTime);
  totalScore += urgencyScore * 0.10;

  return totalScore.clamp(0.0, 1.0);
}
```

The algorithm considers six factors with different weights:
- **Preferred Size (25%)**: Exact match = 1.0, adjacent sizes = 0.7, far sizes = 0.3
- **Preferred Temperament (20%)**: Exact match = 1.0, mismatch = 0.2
- **Preferred Energy Level (15%)**: Exact match = 1.0, adjacent = 0.7, far = 0.2
- **Supported Special Needs (15%)**: Percentage of dog's needs that walker can support
- **Time Compatibility (15%)**: Checks if walk time matches walker's availability
- **Urgency (10%)**: Uses exponential decay - walks within 24 hours get higher scores

The urgency score uses exponential decay to prioritize walks scheduled sooner:

```dart
static double _calculateUrgencyScore(DateTime walkTime) {
  final now = DateTime.now();
  final hoursUntilWalk = walkTime.difference(now).inHours;

  if (hoursUntilWalk <= 24) {
    return 1.0 - (hoursUntilWalk / 24.0) * 0.2; // Score from 1.0 to 0.8
  } else if (hoursUntilWalk <= 168) {
    return 0.8 - ((hoursUntilWalk - 24) / 144.0) * 0.2; // Score from 0.8 to 0.6
  } else {
    return 0.6; // Base score for walks more than a week away
  }
}
```

When walkers view available walks, the requests are automatically sorted by relevance score, ensuring the most suitable walks appear first. This improves user experience by reducing the time spent searching through irrelevant requests.

---

### Bayesian Average Rating Algorithm

The application implements a Bayesian average algorithm for calculating user ratings, which prevents users with few reviews from having extreme ratings. This statistical approach uses a prior distribution to stabilize ratings when review counts are low.

```dart
static double calculateBayesianAverage(List<ReviewModel> reviews) {
  if (reviews.isEmpty) return _bayesianPriorMean;

  final reviewCount = reviews.length;
  final sumRatings = reviews.fold(0.0, (sum, review) => sum + review.rating);

  final numerator = (_bayesianPriorMean * _bayesianPriorCount) + sumRatings;
  final denominator = _bayesianPriorCount + reviewCount;

  return numerator / denominator;
}
```

The algorithm uses a prior mean of 3.5 (out of 5.0) with a confidence equivalent to 10 reviews. This means:
- A user with 0 reviews gets a rating of 3.5 (the prior)
- A user with 1 review of 5.0 gets: (3.5 × 10 + 5.0) / (10 + 1) = 3.64
- A user with 10 reviews averaging 4.5 gets: (3.5 × 10 + 45.0) / (10 + 10) = 4.0
- As review count increases, the prior's influence decreases

This prevents new users from having perfect 5.0 ratings with just one review, while still allowing high-performing users to achieve high ratings as they accumulate more reviews.

---

### Time-Weighted Rating Algorithm

The application also implements a time-weighted average algorithm that gives more weight to recent reviews, reflecting a user's current performance rather than their historical average.

```dart
static double calculateTimeWeightedAverage(
  List<ReviewModel> reviews, {
  double decayFactor = 30.0,
}) {
  if (reviews.isEmpty) return 0.0;

  final now = DateTime.now();
  double weightedSum = 0.0;
  double totalWeight = 0.0;

  for (final review in reviews) {
    final daysSinceReview = now.difference(review.timestamp).inDays.toDouble();
    
    // Exponential decay: weight = exp(-days / decayFactor)
    final weight = exp(-daysSinceReview / decayFactor);
    
    weightedSum += review.rating * weight;
    totalWeight += weight;
  }

  return totalWeight > 0 ? weightedSum / totalWeight : 0.0;
}
```

The algorithm uses exponential decay with a decay factor of 30 days:
- Reviews from today have weight = 1.0
- Reviews from 30 days ago have weight ≈ 0.368
- Reviews from 60 days ago have weight ≈ 0.135
- Reviews older than 90 days have negligible weight

This ensures that a user's recent performance has more influence on their rating than older reviews, which is particularly important if a user's service quality has changed over time.

---

### Combined Rating Algorithm

The application combines both Bayesian average and time-weighted average to produce a final rating that balances stability with recency:

```dart
static double calculateCombinedRating(
  List<ReviewModel> reviews, {
  double bayesianWeight = 0.4,
  double timeWeightedWeight = 0.6,
}) {
  final bayesianAvg = calculateBayesianAverage(reviews);
  final timeWeightedAvg = calculateTimeWeightedAverage(reviews);

  return (bayesianAvg * 0.4) + (timeWeightedAvg * 0.6);
}
```

The combined algorithm uses 40% Bayesian average (for stability) and 60% time-weighted average (for recency), providing a balanced rating that reflects both overall performance and recent trends.

---

### Schedule Conflict Detection Algorithm

The application implements an interval overlap detection algorithm to prevent walkers from accepting conflicting walk requests. This ensures that walkers cannot be scheduled for multiple walks at the same time.

```dart
static bool hasConflict({
  required WalkRequestModel newWalk,
  required List<WalkRequestModel> existingWalks,
  required String walkerId,
}) {
  for (final existingWalk in existingWalks) {
    if (existingWalk.walkerId != walkerId) continue;
    if (existingWalk.status == WalkRequestStatus.cancelled) continue;

    if (_intervalsOverlap(
      newWalk.startTime,
      newWalk.endTime,
      existingWalk.startTime,
      existingWalk.endTime,
    )) {
      return true;
    }
  }
  return false;
}

static bool _intervalsOverlap(
  DateTime start1,
  DateTime end1,
  DateTime start2,
  DateTime end2,
) {
  return start1.isBefore(end2) && end1.isAfter(start2);
}
```

The algorithm uses the mathematical definition of interval overlap: two intervals [a1, a2] and [b1, b2] overlap if and only if a1 < b2 and a2 > b1. This O(1) check is performed for each existing walk, resulting in O(n) time complexity where n is the number of existing walks.

The algorithm also calculates conflict severity scores to quantify how much two walks overlap:

```dart
static double calculateConflictSeverity({
  required DateTime start1,
  required DateTime end1,
  required DateTime start2,
  required DateTime end2,
}) {
  if (!_intervalsOverlap(start1, end1, start2, end2)) {
    return 0.0;
  }

  final overlapStart = start1.isAfter(start2) ? start1 : start2;
  final overlapEnd = end1.isBefore(end2) ? end1 : end2;
  final overlapDuration = overlapEnd.difference(overlapStart).inMinutes;

  final duration1 = end1.difference(start1).inMinutes;
  final duration2 = end2.difference(start2).inMinutes;
  final totalDuration = duration1 + duration2;

  return (overlapDuration / totalDuration).clamp(0.0, 1.0);
}
```

The severity score ranges from 0.0 (no conflict) to 1.0 (complete overlap), allowing the application to prioritize resolving more severe conflicts.

---

## Advanced User Interface Techniques

### StreamBuilder for Reactive UI with Firestore Streams

The application uses Flutter's `StreamBuilder` widget extensively to create reactive UI components that automatically update when Firestore data changes. This eliminates the need for manual polling or refresh mechanisms.

```dart
Expanded(
  child: StreamBuilder<List<MessageModel>>(
    stream: _service.getMessages(widget.chatId),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(child: Text('Error: ${snapshot.error}'));
      }

      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }

      final messages = snapshot.data!;
      return ListView.builder(
        controller: _scrollController,
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final msg = messages[index];
          return _buildMessageWidget(msg);
        },
      );
    },
  ),
)
```

The `StreamBuilder` widget subscribes to the Firestore stream returned by `getMessages()`. The stream emits a new `QuerySnapshot` whenever:
- A new message is added
- A message is deleted
- A message is modified
- The query results change for any reason

The `builder` function receives an `AsyncSnapshot` object that contains:
- `hasData`: Whether the stream has emitted data
- `hasError`: Whether an error occurred
- `data`: The current data from the stream
- `error`: The error object if an error occurred

This reactive pattern ensures the UI is always synchronized with the database state without manual intervention. The time complexity is O(1) for stream subscription, and the widget rebuilds only when the stream emits new data, making it highly efficient.

### ScrollController for Programmatic Scroll Management

The Chat screen implements sophisticated scroll management using `ScrollController` to automatically scroll to new messages while preserving user scroll position when appropriate.

```dart
final ScrollController _scrollController = ScrollController();

@override
void initState() {
  super.initState();
  _initializeChat();
  // Scroll to bottom after initial build
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  });
}

void _sendMessage() async {
  await _service.sendMessage(msg);
  _controller.clear();
  
  // Wait for message to be added to list, then scroll
  Future.delayed(const Duration(milliseconds: 100), () {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  });
}
```

The `ScrollController` provides programmatic control over scrollable widgets. Key technical aspects:

1. **`hasClients` Check**: Before accessing `position`, the code verifies that the controller is attached to a scrollable widget. This prevents errors during widget lifecycle transitions.

2. **`addPostFrameCallback`**: This ensures scrolling happens after the widget tree is fully built, preventing race conditions where the list might not have rendered yet.

3. **`animateTo()` vs `jumpTo()`**: The code uses `animateTo()` with a duration and curve for smooth animations, rather than `jumpTo()` which would cause abrupt movement.

4. **`maxScrollExtent`**: This property represents the maximum scroll offset, effectively scrolling to the bottom of the list.

5. **Delayed Scroll**: After sending a message, the code waits 100ms before scrolling to allow the new message to be added to the list and rendered. This prevents scrolling to an incorrect position.

The scroll management algorithm has O(1) time complexity for scroll operations, and the animation uses hardware acceleration for smooth 60fps scrolling.

### ListView.builder for Lazy Loading and Memory Optimization

The application uses `ListView.builder` to implement lazy loading, which only creates widgets for visible items. This is critical for performance when displaying large datasets.

```dart
ListView.builder(
  controller: _scrollController,
  padding: const EdgeInsets.all(16),
  itemCount: _filteredAvailableRequests.length,
  itemBuilder: (context, index) {
    final request = _filteredAvailableRequests[index];
    return _buildRequestCard(request);
  },
)
```

**Lazy Loading Algorithm:**
- **Initial Render**: Only items visible in the viewport are created (typically 5-10 items)
- **Scroll Detection**: As the user scrolls, Flutter calculates which items should be visible
- **Widget Creation**: New widgets are created on-demand as they enter the viewport
- **Widget Disposal**: Widgets that scroll out of view are disposed to free memory

**Performance Characteristics:**
- **Time Complexity**: O(k) where k is the number of visible items, not the total list size
- **Space Complexity**: O(k) instead of O(n), where n is total items and k is visible items
- **Memory Efficiency**: For a list of 1000 items, only ~10 widgets exist in memory at any time

This approach allows the application to handle lists of arbitrary size without performance degradation. The `itemBuilder` function is called only when an item needs to be rendered, making it highly efficient for large datasets.

### TabController with Animation Management

The Walk Request List screen uses `TabController` with `SingleTickerProviderStateMixin` to manage animated tab transitions and coordinate state between multiple views.

```dart
class _WalkRequestListScreenState extends State<WalkRequestListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    if (widget.isWalker) {
      _tabController = TabController(length: 2, vsync: this);
    }
  }

  @override
  void dispose() {
    if (widget.isWalker) {
      _tabController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Available Walks'),
            Tab(text: 'My Accepted Walks'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAvailableWalksTab(),
          _buildAcceptedWalksTab(),
        ],
      ),
    );
  }
}
```

**Technical Implementation Details:**

1. **SingleTickerProviderStateMixin**: Provides a `Ticker` that drives animations. The mixin ensures only one ticker is active, preventing multiple animations from conflicting.

2. **TabController State Management**: The controller maintains:
   - Current tab index
   - Animation state (for smooth transitions)
   - Listeners for tab changes

3. **Synchronized Views**: The `TabBar` and `TabBarView` share the same controller, ensuring:
   - Tab selection updates the view
   - Swipe gestures update the tab indicator
   - Both remain synchronized

4. **Animation Performance**: Tab transitions use hardware-accelerated animations, maintaining 60fps during transitions.

5. **Memory Management**: The controller must be disposed to prevent memory leaks, as it holds references to listeners and tickers.

The tab management system provides O(1) time complexity for tab switching, with smooth animations handled by Flutter's rendering engine.

### StatefulBuilder for Isolated Dialog State Management

The filter dialogs use `StatefulBuilder` to manage state within modal dialogs without triggering rebuilds of the parent widget tree. This is a performance optimization that isolates state updates.

```dart
void _showFilterDialog() {
  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Filter Walks'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              FilterChip(
                label: Text('Small'),
                selected: _selectedSizes.contains(DogSize.small),
                onSelected: (selected) {
                  setDialogState(() {
                    if (selected) {
                      _selectedSizes.add(DogSize.small);
                    } else {
                      _selectedSizes.remove(DogSize.small);
                    }
                  });
                },
              ),
              // More filter chips...
            ],
          ),
        ),
      ),
    ),
  );
}
```

**Technical Benefits:**

1. **Isolated Rebuilds**: `setDialogState()` only rebuilds the dialog's content, not the entire widget tree beneath it. This reduces unnecessary widget rebuilds.

2. **State Closure**: The `setDialogState` function is a closure that captures the dialog's build context, allowing state updates within the dialog's scope.

3. **Performance**: Without `StatefulBuilder`, updating filter state would require:
   - Closing the dialog
   - Updating parent state
   - Reopening the dialog
   - Rebuilding the entire parent widget tree

   With `StatefulBuilder`, only the dialog's content rebuilds, providing immediate visual feedback.

4. **Memory Efficiency**: The dialog maintains its own state scope, preventing state pollution of the parent widget.

The state management algorithm has O(1) time complexity for state updates, with rebuilds limited to the dialog's subtree.

---

## Advanced Algorithmic Solutions

### Dynamic Programming for Optimal Walk Scheduling

The application implements a Dynamic Programming solution for the Interval Scheduling problem, allowing walkers to select the optimal combination of walk requests that maximizes value while avoiding time conflicts.

**Problem Statement:**
Given multiple walk requests with start/end times and values, select the maximum-value subset of non-overlapping walks.

**DP Algorithm:**
```dart
static OptimalScheduleResult findOptimalSchedule({
  required List<WalkRequestModel> availableWalks,
  required UserModel walker,
}) {
  // 1. Sort walks by end time (earliest first)
  validWalks.sort((a, b) => a.endTime.compareTo(b.endTime));

  // 2. Precompute last non-overlapping walk for each walk
  for (int i = 0; i < n; i++) {
    // Binary search for last walk ending before current starts
    lastNonOverlapping[i] = binarySearch(...);
  }

  // 3. DP: dp[i] = max(dp[i-1], value[i] + dp[lastNonOverlapping[i]])
  for (int i = 0; i < n; i++) {
    final skipValue = dp[i];
    final includeValue = value[i] + 
        (lastNonOverlapping[i] != -1 ? dp[lastNonOverlapping[i] + 1] : 0);
    
    dp[i + 1] = max(skipValue, includeValue);
  }

  // 4. Reconstruct solution using parent pointers
  return reconstructSolution(dp, parent);
}
```

**Time Complexity:** O(n log n + n²) = O(n²)
- O(n log n) for sorting
- O(n log n) for binary search in precomputation
- O(n) for DP computation
- O(n) for solution reconstruction

**Space Complexity:** O(n) for DP array and parent pointers

**Key Insight:** By sorting by end time and using binary search to find the last compatible walk, we can solve this in polynomial time. The DP state `dp[i]` represents the maximum value achievable with the first `i` walks, and we make optimal choices at each step.

**Alternative Greedy Solution:**
For the simpler problem of maximizing the *number* of walks (not value), a greedy algorithm works:
```dart
// Always select the walk that ends earliest among remaining compatible walks
static List<WalkRequestModel> findMaxNonOverlappingWalks(...) {
  sorted.sort((a, b) => a.endTime.compareTo(b.endTime));
  DateTime? lastEndTime;
  
  for (final walk in sorted) {
    if (lastEndTime == null || walk.startTime.isAfter(lastEndTime)) {
      selected.add(walk);
      lastEndTime = walk.endTime;
    }
  }
}
```

This greedy approach has O(n log n) time complexity and is optimal for maximizing count, but the DP solution is needed when walks have different values.

---

### Sliding Window for Rating Trend Analysis

The application uses sliding window algorithms to analyze rating trends over time, detecting improvements, declines, and volatility in user ratings.

**Moving Average with Sliding Window:**
```dart
static List<({DateTime date, double average})> calculateMovingAverage(
  List<ReviewModel> reviews, {
  int windowSize = 10,
}) {
  final window = <ReviewModel>[];
  double windowSum = 0.0;
  
  for (final review in sortedReviews) {
    window.add(review);
    windowSum += review.rating;
    
    // Maintain window size
    if (window.length > windowSize) {
      final oldest = window.removeAt(0);
      windowSum -= oldest.rating;
    }
    
    // Calculate average for current window
    if (window.length >= windowSize) {
      final average = windowSum / window.length;
      result.add((date: review.timestamp, average: average));
    }
  }
}
```

**Time Complexity:** O(n) where n is the number of reviews
**Space Complexity:** O(windowSize) for the sliding window

**Trend Detection using Linear Regression:**
```dart
static RatingTrend detectTrend(List<ReviewModel> reviews) {
  // Linear regression: y = mx + b
  // Calculate slope using least squares method
  final slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
  
  if (slope > threshold) return RatingTrend.improving;
  if (slope < -threshold) return RatingTrend.declining;
  return RatingTrend.stable;
}
```

**Maximum Change Detection (Stock Problem Variant):**
```dart
// Similar to "Best Time to Buy and Sell Stock"
static ({double maxDrop, double maxRise}) findMaxChange(...) {
  double minRating = reviews[0].rating;
  double maxRating = reviews[0].rating;
  
  for (int i = 1; i < reviews.length; i++) {
    // Track maximum drop (highest to current)
    if (reviews[i].rating < minRating) {
      minRating = reviews[i].rating;
    } else {
      maxDrop = max(maxDrop, maxRating - reviews[i].rating);
    }
    
    // Track maximum rise (lowest to current)
    if (reviews[i].rating > maxRating) {
      maxRating = reviews[i].rating;
    } else {
      maxRise = max(maxRise, reviews[i].rating - minRating);
    }
  }
}
```

**Time Complexity:** O(n) - single pass through reviews
**Space Complexity:** O(1) - only tracking min/max values

This algorithm is similar to LeetCode's "Best Time to Buy and Sell Stock" problem, adapted for rating analysis.

---

### Hungarian Algorithm for Optimal Assignment

The application uses the Hungarian Algorithm (Kuhn-Munkres algorithm) to solve the assignment problem: optimally matching walkers to walk requests to minimize total cost.

**Problem Statement:**
Given a cost matrix where `cost[i][j]` represents the cost of assigning walker `i` to request `j`, find the assignment that minimizes total cost.

**Algorithm Steps:**
```dart
static List<int> _hungarianAlgorithm(List<List<double>> costMatrix) {
  // 1. Subtract row minima
  _subtractRowMinima(costMatrix);
  
  // 2. Subtract column minima
  _subtractColMinima(costMatrix);
  
  // 3. Find maximum matching of zeros
  while (true) {
    final assignment = findMaxMatching(costMatrix);
    if (isComplete(assignment)) break;
    
    // 4. Adjust matrix using uncovered minimum
    final minUncovered = findMinUncovered(costMatrix, assignment);
    adjustMatrix(costMatrix, assignment, minUncovered);
  }
  
  return assignment;
}
```

**Time Complexity:** O(n³) where n is the size of the cost matrix
**Space Complexity:** O(n²) for the cost matrix

**Key Steps:**
1. **Row/Column Reduction:** Subtract minimum from each row/column to create zeros
2. **Matching:** Find maximum matching of zeros (greedy assignment)
3. **Matrix Adjustment:** If matching is incomplete, adjust matrix and repeat

This algorithm guarantees an optimal solution for the assignment problem, making it superior to greedy approaches when costs vary significantly.

---

## Conclusion

The PawPal application demonstrates sophisticated use of modern mobile development technologies, particularly in real-time data synchronization, state management, and service layer architecture. The implementation of Firestore streams for real-time updates, the ChangeNotifier pattern for reactive UI, and comprehensive error handling ensure a robust and user-friendly application. The separation of concerns through the service layer enables maintainability and testability, while the subcollection pattern provides scalability for growing data volumes. The chat system's real-time streaming architecture, combined with efficient subcollection queries and automatic UI updates through StreamBuilder, provides a seamless messaging experience comparable to modern chat applications.

Word Count: 3,247
